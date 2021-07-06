defmodule WebengineKiosk.Options.ContextMenu do
  @all_options [
    # Constant	Value	Description
    NoContextMenu, # the widget does not feature a context menu, context menu handling is deferred to the widget's parent.
    PreventContextMenu, #	4	the widget does not feature a context menu, and in contrast to NoContextMenu, the handling is not deferred to the widget's parent. This means that all right mouse button events are guaranteed to be delivered to the widget itself through QWidget::mousePressEvent(), and QWidget::mouseReleaseEvent().
    DefaultContextMenu, #	1	the widget's QWidget::contextMenuEvent() handler is called.
    ActionsContextMenu, #	2	the widget displays its QWidget::actions() as context menu.
    CustomContextMenu, #	3	the widget emits the QWidget::customContextMenuRequested() signal.
  ]

  @moduledoc """
    Context menu options:
      NoContextMenu: the widget does not feature a context menu, context menu handling is deferred to the widget's parent.
      PreventContextMenu: the widget does not feature a context menu, and in contrast to NoContextMenu, the handling is not deferred to the widget's parent. This means that all right mouse button events are guaranteed to be delivered to the widget itself through QWidget::mousePressEvent(), and QWidget::mouseReleaseEvent().
      DefaultContextMenu: the widget's QWidget::contextMenuEvent() handler is called.
      ActionsContextMenu: the widget displays its QWidget::actions() as context menu.
      CustomContextMenu: the widget emits the QWidget::customContextMenuRequested() signal.
  """

  @doc """
    Check the argument
  """
  def check_arg({:context_menu, arg}) do
    case arg in @all_options do
      true -> :ok
      false -> {:error, "Unknown option #{inspect(arg)}"}
    end
  end

end
