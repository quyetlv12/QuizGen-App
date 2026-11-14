# Toast placement

Reference: user screenshot of the quiz completion toast overlapping home content.
Keep the existing typography, success green and status icons. Show transient
messages in the root overlay, 8 logical pixels below the top safe area, with
16px side margins and a 608px maximum width on desktop. Keep long messages
readable with wrapping and scrolling. Keyboard and bottom navigation must not
change the toast position. New messages replace the current toast; each expires
after six seconds and supports an accessible close button.
