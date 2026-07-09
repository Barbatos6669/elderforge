# Chat UI Scripts

Chat UI lives here.

Files:

- `chat_panel.gd`: bottom-left in-game chat box. It focuses on UI only:
  opening the input, sending typed text to `MultiplayerTestManager`, and
  rendering messages received from the network layer.

GDScript notes:

- `text_submitted` is a `LineEdit` signal. It fires when the player presses
  Enter while the input has focus.
- `blocks_world_input()` is called by `PlayerController` through the
  `blocking_world_input` group, so typing does not also move or attack.
- The chat panel does not send ENet RPCs itself. It calls a narrow method on
  the network manager, which keeps validation and relay behavior centralized.
