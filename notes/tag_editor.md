
the tag editor:
tag_editor_outer_frame = {
  tag_editor_inner_frame = {
    tag_editor_top_row = {
      tag_editor_title_row = {
        title_row_label.text = {'tag_editor_title'}
        title_row_draggable -- a draggable handle
        title_row_close_button -- a close button with a bold X
      }
    }
    tag_editor_content_frame = {
      tag_editor_content_inner_frame -- invisible frame = {
        tag_editor_last_user_row = {
          last_user_row_last_user_container = {
            last_user_row_last_user_title.text = {'last_user_row_title'}
            last_user_row_last_user_name.text = player.name
          },
          last_user_row_button_container = {
            last_user_row_move_button -- mipmapped move icon, light-grey
            last_user_row_delete_button -- trash can icon, red
          }
        },

        tag_editor_teleport_row = {
          teleport_row_label.text = {'teleport_to'},
          teleport_row_teleport_button.text = gps coord string
        },

        tag_editor_favorite_row = {
          favorite_row_label.text = {'favorite_row_label'},
          favorite_row_favorite_button = PlayerFavorites.is_player_favorite(player) (or similar)
        },

        tag_editor_icon_row = {
          icon_row_label.text = {'icon_row_label'},
          icon_row_icon_button = tag.chart_tag.icon or blank
        },

        tag_editor_text_row = {
          text_row_label.text = {'text_row_label'},
          text_row_text_box.text = tag.chart_tag.text
        }
      }
    },
    tag_editor_last_row = {
      last_row_cancel_button.text = {'cancel_button'}
      last_row_confirm_button.text = {'confirm_button'}
    }
  }
}

use the builder pattern for this and all guis! use command pattern to handle user and event interaction

the styling should mimic the vanilla "add tag" dialog as much as possible, without the snap_position editor

place this gui into the screen gui and auto-center it

for the most part, this gui should only be active in chart view or chart_zoomed_in

the only time it should show in game mode is when it is opened from a fave_bar button click. 

when the tag_editor is open, any mouse clicks outside the tag editor's outer frame should be ignored

upon opening the player.open should be set to enable esc to close the gui.

if, for some reason, it is possible to have the tag_editor still open when exiting chart or chart_zoomed mode to game mode, then i would like to create an on_tick event to see if the editor is in game view and the editor was not opened by the fave_bar while in game view, then after 30 ticks the tag_editor should self-close. when the tag_editor is closed, the on_tick event should be unregistered (and re-registered upon opening)