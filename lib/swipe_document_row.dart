import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Reveals actions only; dragging never mutates the document.
class SwipeDocumentRow extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRename, onDelete;
  const SwipeDocumentRow({
    super.key,
    required this.child,
    required this.onRename,
    required this.onDelete,
  });
  @override
  State<SwipeDocumentRow> createState() => _SwipeDocumentRowState();
}

class _SwipeDocumentRowState extends State<SwipeDocumentRow> {
  double offset = 0;
  bool busy = false;
  Future<void> act(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      offset = 0;
      busy = true;
    });
    try {
      await action();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 240
          ? constraints.maxWidth * .65
          : 160.0;
      return Semantics(
        customSemanticsActions: {
          const CustomSemanticsAction(label: 'Đổi tên'): () =>
              act(widget.onRename),
          const CustomSemanticsAction(label: 'Xóa'): () => act(widget.onDelete),
        },
        child: ClipRect(
          child: Stack(
            children: [
              if (offset < 0)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SizedBox(
                      width: width,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () => act(widget.onRename),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_outlined),
                                  Text('Đổi tên'),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                              onPressed: busy
                                  ? null
                                  : () => act(widget.onDelete),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline),
                                  Text('Xóa'),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              GestureDetector(
                onHorizontalDragUpdate: busy
                    ? null
                    : (d) => setState(
                        () => offset = (offset + d.delta.dx).clamp(-width, 0),
                      ),
                onHorizontalDragEnd: busy
                    ? null
                    : (d) => setState(
                        () => offset = offset < -width / 4 ? -width : 0,
                      ),
                onHorizontalDragCancel: () => setState(() => offset = 0),
                child: Transform.translate(
                  offset: Offset(offset, 0),
                  child: widget.child,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
