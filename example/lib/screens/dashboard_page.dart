import 'dart:math';

import 'package:dashboard/dashboard.dart';
import 'package:example/add_dialog.dart';
import 'package:example/data_widget.dart';
import 'package:example/storage.dart';
import 'package:flutter/material.dart';

class MySlotBackground extends SlotBackgroundBuilder<ColoredDashboardItem> {
  @override
  Widget? buildBackground(BuildContext context, ColoredDashboardItem? item, int x, int y, bool editing) {
    if (item != null) {
      return Container(
        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
      );
    }

    return null;
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final ScrollController scrollController = ScrollController();

  late var _itemController = DashboardItemController<ColoredDashboardItem>.withDelegate(itemStorageDelegate: storage);

  bool refreshing = false;

  var storage = MyItemStorage();

  //var dummyItemController =
  //    DashboardItemController<ColoredDashboardItem>(items: []);

  DashboardItemController<ColoredDashboardItem> get itemController => _itemController;

  int? slot;

  setSlot() {
    var w = MediaQuery.of(context).size.width;
    setState(() {
      slot = w > 600
          ? w > 900
              ? 8
              : 6
          : 4;
    });
  }

  List<String> d = [];

  // Affiche une boîte de dialogue pour confirmer ou annuler les changements
  Future<void> _showExitEditingDialog() async {
    // Si aucune modification en attente, quitter simplement le mode édition
    if (!itemController.hasPendingChanges) {
      itemController.exitEditing(true);
      setState(() {});
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mode édition'),
        content: const Text('Voulez-vous sauvegarder les modifications?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler les changements'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );

    if (result != null) {
      itemController.exitEditing(result);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    var w = MediaQuery.of(context).size.width;
    slot = w > 600
        ? w > 900
            ? 8
            : 6
        : 4;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: itemController.isEditing ? Colors.orange : const Color(0xFF4285F4),
        title: itemController.isEditing ? const Text('Mode Édition') : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
              onPressed: () async {
                await storage.clear();
                setState(() {
                  refreshing = true;
                });
                storage = MyItemStorage();
                _itemController = DashboardItemController.withDelegate(itemStorageDelegate: storage);
                Future.delayed(const Duration(milliseconds: 150)).then((value) {
                  setState(() {
                    refreshing = false;
                  });
                });
              },
              icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () {
                itemController.clear();
              },
              icon: const Icon(Icons.delete)),
          IconButton(
              onPressed: () {
                add(context);
              },
              icon: const Icon(Icons.add)),
          if (itemController.isEditing)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    _showExitEditingDialog();
                  },
                  icon: Icon(
                    Icons.check,
                    color: itemController.hasPendingChanges ? Colors.green : null,
                  ),
                ),
                if (itemController.hasPendingChanges)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          if (itemController.isEditing)
            IconButton(
              onPressed: () {
                itemController.exitEditing(false);
                setState(() {});
              },
              icon: Icon(
                Icons.close,
                color: itemController.hasPendingChanges ? Colors.red : null,
              ),
            ),
          if (!itemController.isEditing)
            IconButton(
              onPressed: () {
                itemController.startEditing();
                setState(() {});
              },
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: SafeArea(
        child: refreshing
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Dashboard<ColoredDashboardItem>(
                scrollController: scrollController,
                shrinkToPlace: false,
                slideToTop: true,
                removeEmptyRows: true,
                absorbPointer: false,
                slotBackgroundBuilder: SlotBackgroundBuilder.withFunction((context, item, x, y, editing) {
                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12, width: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }),
                padding: const EdgeInsets.all(8),
                horizontalSpace: 8,
                verticalSpace: 8,
                slotAspectRatio: 1,
                animateEverytime: true,
                dashboardItemController: itemController,
                slotCount: slot!,
                errorPlaceholder: (e, s) {
                  return Text("$e , $s");
                },
                emptyPlaceholder: const Center(child: Text("Empty")),
                itemStyle: ItemStyle(
                    color: Colors.transparent,
                    clipBehavior: Clip.antiAliasWithSaveLayer,
                    elevation: 5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                physics: const RangeMaintainingScrollPhysics(),
                editModeSettings: EditModeSettings(
                    draggableOutside: false,
                    paintBackgroundLines: false,
                    autoScroll: true,
                    resizeCursorSide: 15,
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 300),
                    backgroundStyle:
                        const EditModeBackgroundStyle(lineColor: Colors.black38, lineWidth: 0.5, dualLineHorizontal: false, dualLineVertical: false)),
                itemBuilder: (ColoredDashboardItem item) {
                  var layout = item.layoutData;

                  if (item.data != null) {
                    return DataWidget(
                      item: item,
                    );
                  }

                  return LayoutBuilder(builder: (_, c) {
                    return Stack(
                      children: [
                        Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(10)),
                          child: SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: Text(
                                "ID: ${item.identifier}\n${[
                                  "x: ${layout.startX}",
                                  "y: ${layout.startY}",
                                  "w: ${layout.width}",
                                  "h: ${layout.height}",
                                  if (layout.minWidth != 1) "minW: ${layout.minWidth}",
                                  if (layout.minHeight != 1) "minH: ${layout.minHeight}",
                                  if (layout.maxWidth != null) "maxW: ${layout.maxWidth}",
                                  if (layout.maxHeight != null) "maxH : ${layout.maxHeight}"
                                ].join("\n")}",
                                style: const TextStyle(color: Colors.white),
                              )),
                        ),
                        if (itemController.isEditing)
                          Positioned(
                              right: 5,
                              top: 5,
                              child: InkResponse(
                                  radius: 20,
                                  onTap: () {
                                    itemController.delete(item.identifier);
                                  },
                                  child: const Icon(
                                    Icons.clear,
                                    color: Colors.white,
                                    size: 20,
                                  )))
                      ],
                    );
                  });
                },
              ),
      ),
    );
  }

  Future<void> add(BuildContext context) async {
    var res = await showDialog(
        context: context,
        builder: (c) {
          return const AddDialog();
        });

    if (res != null) {
      itemController.add(
          ColoredDashboardItem(
              color: res[6],
              width: res[0],
              height: res[1],
              startX: 0,
              startY: 0,
              identifier: (Random().nextInt(100000) + 4).toString(),
              minWidth: res[2],
              minHeight: res[3],
              maxWidth: res[4] == 0 ? null : res[4],
              maxHeight: res[5] == 0 ? null : res[5]),
          mountToTop: false);
    }
  }
}
