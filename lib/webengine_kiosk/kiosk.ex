defmodule WebengineKiosk.Kiosk do
  use GenServer
  alias WebengineKiosk.{Message, Options}

  require Logger

  @moduledoc false

  @spec start_link(%{args: Keyword.t(), parent: pid}, GenServer.options()) ::
          {:ok, pid} | {:error, term}
  def start_link(%{args: args, parent: parent}, genserver_opts \\ []) do
    with :ok <- Options.check_args(args) do
      GenServer.start_link(__MODULE__, %{args: args, parent: parent}, genserver_opts)
    end
  end

  def init(%{args: args, parent: parent}) do
    priv_dir = :code.priv_dir(:webengine_kiosk)
    cmd = Path.join(priv_dir, "kiosk")

    if !File.exists?(cmd) do
      _ = Logger.error("Kiosk port application is missing. It should be at #{cmd}.")
      raise "Kiosk port missing"
    end

    cmd_options = Options.add_defaults(args)
    system_args = Options.system_args(args)

    cmd_args =
      cmd_options
      |> Enum.flat_map(fn {key, value} -> ["--#{key}", to_string(value)] end)

    Logger.info("cmd_args: #{inspect cmd_args}")

    # System setup
    system_args
    |> set_permissions!()
    |> platform_init_events!()
    |> fix_shared_memory!()
    |> set_xdg_cache!()

    homepage = Keyword.get(cmd_options, :homepage)

    port =
      Port.open({:spawn_executable, cmd}, [
        {:args, cmd_args},
        {:cd, priv_dir},
        {:packet, 2},
        :use_stdio,
        :binary,
        :exit_status
      ])

    {:ok, %{port: port, homepage: homepage, parent: parent, system_args: system_args}}
  end

  def handle_call(:go_home, _from, state) do
    send_port(state, Message.go_to_url(state.homepage))
    {:reply, :ok, state}
  end

  def handle_call({:go_to_url, url}, _from, state) do
    send_port(state, Message.go_to_url(url))
    {:reply, :ok, state}
  end

  def handle_call({:run_javascript, code}, _from, state) do
    send_port(state, Message.run_javascript(code))
    {:reply, :ok, state}
  end

  def handle_call({:blank, yes}, _from, state) do
    send_port(state, Message.blank(yes))
    {:reply, :ok, state}
  end

  def handle_call(:reload, _from, state) do
    send_port(state, Message.reload())
    {:reply, :ok, state}
  end

  def handle_call(:back, _from, state) do
    send_port(state, Message.go_back())
    {:reply, :ok, state}
  end

  def handle_call(:forward, _from, state) do
    send_port(state, Message.go_forward())
    {:reply, :ok, state}
  end

  def handle_call(:stop_loading, _from, state) do
    send_port(state, Message.stop_loading())
    {:reply, :ok, state}
  end

  def handle_call({:set_zoom, factor}, _from, state) do
    send_port(state, Message.set_zoom(factor))
    {:reply, :ok, state}
  end

  def handle_info({_, {:data, raw_message}}, state) do
    raw_message
    |> Message.decode()
    |> handle_browser_message(state)
  end

  def handle_info({port, {:exit_status, 0}}, %{port: port} = state) do
    _ = Logger.info("webengine_kiosk: normal exit from port")
    {:stop, :normal, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    _ = Logger.error("webengine_kiosk: unexpected exit from port: #{status}")
    {:stop, :unexpected_exit, state}
  end

  defp handle_browser_message({:browser_crashed, reason, _exit_status}, state) do
    _ =
      Logger.error(
        "webengine_kiosk: browser crashed: #{inspect(reason)}. Going home and hoping..."
      )

    send_event(state.parent, {:browser_crashed, reason})

    # Try to recover by going back home
    send_port(state, Message.go_to_url(state.homepage))
    {:noreply, state}
  end

  defp handle_browser_message({:console_log, log}, state) do
    _ = Logger.warn("webengine_kiosk(stderr): #{log}")
    send_event(state.parent, {:console_log, log})
    {:noreply, state}
  end

  defp handle_browser_message(message, state) do
    _ = Logger.debug("webengine_kiosk: received #{inspect(message)}")
    send_event(state.parent, message)
    {:noreply, state}
  end

  defp send_event(parent, event) do
    WebengineKiosk.dispatch_event(parent, event)
  end

  defp send_port(state, message) do
    send(state.port, {self(), {:command, message}})
  end

  defp platform_init_events!(opts) do
    udev_opt = Keyword.get(opts, :platform_udev, false)

    udev_init_delay_ms =
      case udev_opt do
        val when is_integer(val) -> udev_opt
        _other -> 1_000
      end

    unless udev_opt == false do
      # Initialize eudev
      Logger.debug("webengine_kiosk: platform_init_event! ")
      :os.cmd('udevd -d')
      :os.cmd('udevadm trigger --type=subsystems --action=add')
      :os.cmd('udevadm trigger --type=devices --action=add')
      :os.cmd('udevadm settle --timeout=30')
      Process.sleep(udev_init_delay_ms)
    end

    opts
  end

  def set_xdg_cache!(opts) do
    if Keyword.get(opts, :platform_cache_dir, false) do
      Logger.debug("webengine_kiosk: set_xdg_cache! ")
      System.put_env("XDG_RUNTIME_DIR", "/root/cache/")
    end

    opts
  end

  def fix_shared_memory!(opts) do
    shared_memory_opt = Keyword.get(opts, :platform_shared_memory, false)

    if shared_memory_opt do
      Logger.debug("webengine_kiosk: fix_shared_memory! ")
      # webengine (aka chromium) uses /dev/shm for shared memory.
      # On Nerves it maps to devtmpfs which is waay too small.
      # Haven't found an option to set the shm file, so we get this hack:
      File.rm_rf("/root/shm")
      File.mkdir_p!("/root/shm")
      File.rm_rf("/dev/shm")
      File.ln_s!("/root/shm", "/dev/shm")
      Process.sleep(100)
    end

    opts
  end

  defp set_permissions!(opts) do
    # Check if we are on a raspberry pi
    if File.exists?("/dev/vchiq") do
      File.chgrp("/dev/vchiq", 28)
      File.chmod("/dev/vchiq", 0o660)
    end

    if data_dir = Keyword.get(opts, :data_dir) do
      File.mkdir_p(data_dir)

      if uid = Keyword.get(opts, :uid) do
        chown(data_dir, uid)
      end
    end

    opts
  end

  defp chown(file, uid) when is_binary(uid) do
    case System.cmd("id", ["-u", uid]) do
      {uid, 0} ->
        uid =
          String.trim(uid)
          |> String.to_integer()

        chown(file, uid)

      _ ->
        :error
    end
  end

  defp chown(file, uid) when is_integer(uid) do
    File.chown(file, uid)
  end
end
