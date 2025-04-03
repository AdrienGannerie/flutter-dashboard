part of '../dashboard_base.dart';

/// A controller for dashboard items.
///
/// Every [Dashboard] needs a [DashboardItemController].
/// The controller determines which items will be displayed on the screen.
/// Item addition, removal, etc. operations are done through the controller.
///
/// The controller is also used to enable/disable editing with [isEditing].
/// Use as setter to specify edit mode.
///
/// [itemStorageDelegate] is used to handle changes and save the layout.
/// You can save layout information on remote server or disk.
///
/// New items can be added with [add] or plural [addAll].
///
/// Items can be deleted with [delete] or plural [deleteAll].
/// For deleting all items can be used [clear].
///
class DashboardItemController<T extends DashboardItem> with ChangeNotifier {
  /// You can define items with constructor.
  /// But the layout information is only for the session.
  /// Changes cannot be handled.
  DashboardItemController({
    required List<T> items,
  })  : _items = items.asMap().map(
              (key, value) => MapEntry(value.identifier, value),
            ),
        itemStorageDelegate = null;

  /// You can create [DashboardItemController] with an [itemStorageDelegate].
  /// In init state, item information is brought with the delegate.
  /// The necessary functions of the delegate are triggered on all changes.
  ///
  /// If the delegate is waiting for a Future to load the items, this will throw
  /// error at the end of the [timout].
  DashboardItemController.withDelegate({Duration? timeout, required this.itemStorageDelegate}) : _timeout = timeout ?? const Duration(seconds: 10);

  /// To define [itemStorageDelegate] use [DashboardItemController.withDelegate]
  ///
  /// For more see [DashboardItemStorageDelegate] documentation.
  final DashboardItemStorageDelegate<T>? itemStorageDelegate;

  /// Users can only edit the layout when [isEditing] is true.
  /// The [isEditing] does not have to be true to add or delete items.
  bool get isEditing => _layoutController?.isEditing ?? false;

  /// Vérifie s'il y a des modifications en attente
  bool get hasPendingChanges => _layoutController?.hasPendingChanges ?? false;

  /// Starts the edit mode
  void startEditing() {
    if (_layoutController != null && !isEditing) {
      _layoutController!._startEditing();
    }
  }

  /// Add new item to Dashboard.
  ///
  /// If [itemStorageDelegate] is not null,
  /// [DashboardItemStorageDelegate.onItemsAdded] will call with added item and
  /// its new layout.
  /// It is placed wherever possible. The new layoutData may not be the
  /// same as the one added.
  ///
  /// If the location of the added item is defined, it is tried to be
  /// placed in the location first. If there is a conflict or overflow and
  /// [Dashboard.shrinkToPlace] is true, it is tried to be placed by shrinking.
  /// In this case, if there is more than one possibility, it is placed in
  /// the largest form.
  void add(T item, {bool mountToTop = true, Duration duration = const Duration(milliseconds: 200), Curve curve = Curves.easeInOut}) {
    if (_isAttached) {
      _items[item.identifier] = item;
      _layoutController!.add(item, mountToTop: mountToTop, duration: duration, curve: curve);

      // Ne pas appeler le delegate immédiatement si en mode édition
      if (!isEditing) {
        itemStorageDelegate?._onItemsAdded([_getItemWithLayout(item.identifier)], _layoutController!.slotCount);
      }
      // Sinon le delegate sera appelé lors de la confirmation des changements
    } else {
      throw Exception("Not Attached");
    }
  }

  /// Add new multiple items to Dashboard.
  ///
  /// If [itemStorageDelegate] is not null,
  /// [DashboardItemStorageDelegate.onItemsAdded] will call with added items and
  /// their new layouts.
  /// They are placed wherever possible. The new layoutData may not be the
  /// same as the one added.
  ///
  /// If the location of the added item is defined, it is tried to be
  /// placed in the location first. If there is a conflict or overflow and
  /// [Dashboard.shrinkToPlace] is true, it is tried to be placed by shrinking.
  /// In this case, if there is more than one possibility, it is placed in
  /// the largest form.
  void addAll(List<T> items, {bool mountToTop = true}) {
    if (_isAttached) {
      _items.addAll(items.asMap().map((key, value) => MapEntry(value.identifier, value)));
      _layoutController!.addAll(items, mountToTop: mountToTop);

      // Ne pas appeler le delegate immédiatement si en mode édition
      if (!isEditing) {
        itemStorageDelegate?._onItemsAdded(items.map((e) => _getItemWithLayout(e.identifier)).toList(), _layoutController!.slotCount);
      }
      // Sinon le delegate sera appelé lors de la confirmation des changements
    } else {
      throw Exception("Not Attached");
    }
  }

  /// Delete an item from Dashboard.
  void delete(String id) {
    if (_isAttached) {
      // Sauvegarde l'information de l'élément supprimé pour une utilisation ultérieure
      var deletedItem = _getItemWithLayout(id);

      _layoutController!.delete(id);
      _items.remove(id);

      // Ne pas appeler le delegate immédiatement si en mode édition
      if (!isEditing) {
        itemStorageDelegate?._onItemsDeleted([deletedItem], _layoutController!.slotCount);
      }
      // Sinon le delegate sera appelé lors de la confirmation des changements
    } else {
      throw Exception("Not Attached");
    }
  }

  /// Delete multiple items from Dashboard.
  void deleteAll(List<String> ids) {
    if (_isAttached) {
      // Sauvegarde l'information des éléments supprimés pour une utilisation ultérieure
      var deletedItems = ids.map((e) => _getItemWithLayout(e)).toList();

      _layoutController!.deleteAll(ids);
      _items.removeWhere((k, v) => ids.contains(k));

      // Ne pas appeler le delegate immédiatement si en mode édition
      if (!isEditing) {
        itemStorageDelegate?._onItemsDeleted(deletedItems, _layoutController!.slotCount);
      }
      // Sinon le delegate sera appelé lors de la confirmation des changements
    } else {
      throw Exception("Not Attached");
    }
  }

  /// Clear all items from Dashboard.
  void clear() {
    return deleteAll(items);
  }

  T _getItemWithLayout(String id) {
    if (!_isAttached) throw Exception("Not Attached");
    return _items[id]!..layoutData = _layoutController!._layouts![id]!.origin;
  }

  ///
  late Map<String, T> _items;

  /// Get all items.
  ///
  /// The returned list is unmodifiable. A change negative affects
  /// state management and causes conflicts.
  List<String> get items => List.unmodifiable(_items.values.map((e) => e.identifier));

  Duration? _timeout;

  FutureOr<void> _loadItems(int slotCount) {
    var ftr = itemStorageDelegate!._getAllItems(slotCount);
    if (ftr is Future<List<T>>) {
      if (_asyncSnap == null) {
        _asyncSnap = ValueNotifier(const AsyncSnapshot.waiting());
      } else {
        _asyncSnap!.value = const AsyncSnapshot.waiting();
      }
      var completer = Completer();

      ftr.then((value) {
        _items = value.asMap().map((key, value) => MapEntry(value.identifier, value));

        completer.complete();
        _asyncSnap!.value = AsyncSnapshot.withData(ConnectionState.done, value);
      }).timeout(_timeout!, onTimeout: () {
        completer.complete();
        _asyncSnap!.value = AsyncSnapshot.withError(ConnectionState.none, TimeoutException(null), StackTrace.current);
      }).onError((error, stackTrace) {
        completer.complete();
        _asyncSnap!.value = AsyncSnapshot.withError(ConnectionState.none, error ?? Exception(), stackTrace);
      });

      return Future.sync(() => completer.future);
    } else {
      _items = ftr.asMap().map((key, value) => MapEntry(value.identifier, value));

      if (_asyncSnap == null) {
        _asyncSnap = ValueNotifier(AsyncSnapshot.withData(ConnectionState.done, ftr));
      } else {
        _asyncSnap!.value = AsyncSnapshot.withData(ConnectionState.done, ftr);
      }
      return null;
    }
  }

  ValueNotifier<AsyncSnapshot>? _asyncSnap;

  bool get _isAttached => _layoutController != null;

  _DashboardLayoutController? _layoutController;

  void _attach(_DashboardLayoutController layoutController) {
    _layoutController = layoutController;
  }

  /// Exits edit mode, confirming or canceling pending changes
  ///
  /// If [confirm] is true, all pending changes are saved
  /// If [confirm] is false, all pending changes are discarded
  void exitEditing(bool confirm) {
    if (_isAttached && isEditing) {
      if (confirm) {
        _layoutController!.confirmChanges();
      } else {
        _layoutController!.cancelChanges();
      }
    }
  }
}

/// Définit les différentes zones possibles lors du déplacement d'un élément
enum DropZone {
  /// Zone supérieure d'une case (insérer au-dessus)
  top,

  /// Zone inférieure d'une case (insérer en-dessous)
  bottom,

  /// Zone gauche d'une case (insérer à gauche)
  left,

  /// Zone droite d'une case (insérer à droite)
  right,

  /// Zone centrale d'une case (déplacer tous les éléments)
  center
}

///
class _DashboardLayoutController<T extends DashboardItem> with ChangeNotifier {
  ///
  _DashboardLayoutController();

  ///
  late DashboardItemController<T> itemController;

  ///
  late _ViewportDelegate _viewportDelegate;

  ///
  late int slotCount;

  ///
  late bool shrinkToPlace;

  ///
  late bool swapOnEditing;

  ///
  late bool slideToTop;

  ///
  late bool removeEmptyRows;

  late bool scrollToAdded;

  /// Flag indicating if elements should be pushed on conflict
  late bool pushElementsOnConflict;

  /// Flag indicating if we're in edit mode
  bool _isEditing = false;

  /// Users can only edit the layout when [isEditing] is true.
  bool get isEditing => _isEditing;

  /// Stores the initial layout state before edit mode starts
  Map<String, ItemLayout>? _initialLayouts;

  /// Stores the items that existed at the start of edit mode
  Set<String>? _initialItems;

  /// Tracks items added during edit mode (to remove them if changes are cancelled)
  final Set<String> _itemsAddedDuringEdit = {};

  /// Tracks items deleted during edit mode (to restore them if changes are cancelled)
  final Map<String, T> _itemsDeletedDuringEdit = {};

  /// Stores all pending changes during edit mode
  final Set<String> _pendingChanges = {};

  /// Vérifie s'il y a des modifications en attente
  bool get hasPendingChanges => _pendingChanges.isNotEmpty || _itemsAddedDuringEdit.isNotEmpty || _itemsDeletedDuringEdit.isNotEmpty;

  /// Starts edit mode and captures the initial state
  void _startEditing() {
    if (!_isEditing) {
      // Capture the initial state of all layouts
      _initialLayouts = {};
      _initialItems = {};
      if (_layouts != null) {
        for (var entry in _layouts!.entries) {
          _initialLayouts![entry.key] = entry.value.origin
              .copyWithStarts(startX: entry.value.origin.startX, startY: entry.value.origin.startY)
              .copyWithDimension(width: entry.value.origin.width, height: entry.value.origin.height);
          _initialItems!.add(entry.key);
        }
      }
      _pendingChanges.clear();
      _itemsAddedDuringEdit.clear();
      _itemsDeletedDuringEdit.clear();
      _isEditing = true;
      notifyListeners();
    }
  }

  set isEditing(bool value) {
    if (value != _isEditing) {
      // Entering edit mode
      if (value && !_isEditing) {
        _startEditing();
      }
      // Exiting edit mode with confirmation dialog - only trigger once
      else if (!value && _isEditing) {
        // If there are pending changes, show confirmation dialog
        if (_pendingChanges.isNotEmpty) {
          // This will be handled by the UI layer
          // We don't actually change _isEditing here
          notifyListeners();
          return;
        }
        // If no changes, just exit edit mode normally
        else {
          if (removeEmptyRows) {
            compactLayout();
          }
        }
      }

      _isEditing = value;
      notifyListeners();
    }
  }

  late bool absorbPointer;

  ///
  late double slotEdge, verticalSlotEdge;

  ///
  Map<String, _ItemCurrentLayout>? _layouts;

  final SplayTreeMap<int, String> _startsTree = SplayTreeMap<int, String>();
  final SplayTreeMap<int, String> _endsTree = SplayTreeMap<int, String>();

  final SplayTreeMap<int, String> _indexesTree = SplayTreeMap<int, String>();

  _EditSession? editSession;

  void startEdit(String id, bool transform) {
    editSession = _EditSession(layoutController: this, editing: _layouts![id]!, transform: transform);
  }

  /// Removes empty rows from the layout by moving all items up
  /// This helps create a more condensed layout without empty spaces
  void compactLayout() {
    if (_layouts == null || _layouts!.isEmpty) return;

    // Get the maximum Y coordinate
    int maxY = 0;
    for (var layout in _layouts!.values) {
      int itemEndY = layout.startY + layout.height;
      if (itemEndY > maxY) {
        maxY = itemEndY;
      }
    }

    // Create an array to track which rows are empty
    List<bool> emptyRows = List.generate(maxY, (_) => true);

    // Mark which rows contain items
    for (var layout in _layouts!.values) {
      for (int y = layout.startY; y < layout.startY + layout.height; y++) {
        if (y < emptyRows.length) {
          emptyRows[y] = false;
        }
      }
    }

    // Count empty rows and calculate shifts
    List<int> rowShifts = List.generate(maxY, (_) => 0);
    int emptyCount = 0;

    for (int i = 0; i < emptyRows.length; i++) {
      if (emptyRows[i]) {
        emptyCount++;
      }
      rowShifts[i] = emptyCount;
    }

    // No empty rows found, nothing to do
    if (emptyCount == 0) return;

    // Save current layouts to reindex later
    Map<String, ItemLayout> newLayouts = {};

    // Move all items up based on the number of empty rows above them
    for (var entry in _layouts!.entries) {
      var layout = entry.value;
      int newY = layout.startY - rowShifts[layout.startY];

      // Create new layout with updated Y position
      var newLayout = layout.origin.copyWithStarts(startX: layout.startX, startY: newY);

      newLayouts[entry.key] = newLayout;
    }

    // Clear current indexes
    _startsTree.clear();
    _endsTree.clear();
    _indexesTree.clear();

    // Reindex all items with their new positions
    for (var entry in newLayouts.entries) {
      _indexItem(entry.value, entry.key);
    }

    // Notify controllers about changes
    if (itemController.itemStorageDelegate != null) {
      itemController.itemStorageDelegate!._onItemsUpdated(_layouts!.keys.map((id) => itemController._getItemWithLayout(id)).toList(), slotCount);
    }
  }

  void cancelEditSession() {
    if (editSession == null) return;
    _layouts!.forEach((key, value) {
      value._mount(this, key);
    });
    editSession = null;
  }

  ///
  late Axis _axis;

  void deleteAll(List<String> ids) {
    for (var id in ids) {
      // Si l'élément a été ajouté pendant cette session d'édition,
      // simplement le retirer du suivi des ajouts plutôt que de
      // l'ajouter au suivi des suppressions
      if (_isEditing && _itemsAddedDuringEdit.contains(id)) {
        _itemsAddedDuringEdit.remove(id);
      }
      // Sinon, si c'est un élément qui existait avant l'édition, le suivre comme supprimé
      else if (_isEditing && _initialItems?.contains(id) == true && !_itemsAddedDuringEdit.contains(id)) {
        var item = itemController._items[id];
        if (item != null) {
          _itemsDeletedDuringEdit[id] = item;
        }
      }
    }

    for (var id in ids) {
      var l = _layouts![id];
      var indexes = getItemIndexes(l!.origin);
      _startsTree.remove(indexes.first);
      _endsTree.remove(indexes.last);

      for (var i in indexes) {
        _indexesTree.remove(i);
      }

      _layouts!.remove(id);
    }
    notifyListeners();
  }

  void delete(String id) {
    // Si l'élément a été ajouté pendant cette session d'édition,
    // simplement le retirer du suivi des ajouts plutôt que de
    // l'ajouter au suivi des suppressions
    if (_isEditing && _itemsAddedDuringEdit.contains(id)) {
      _itemsAddedDuringEdit.remove(id);
    }
    // Sinon, si c'est un élément qui existait avant l'édition, le suivre comme supprimé
    else if (_isEditing && _initialItems?.contains(id) == true && !_itemsAddedDuringEdit.contains(id)) {
      var item = itemController._items[id];
      if (item != null) {
        _itemsDeletedDuringEdit[id] = item;
      }
    }

    var l = _layouts![id];
    var indexes = getItemIndexes(l!.origin);
    _startsTree.remove(indexes.first);
    _endsTree.remove(indexes.last);

    for (var i in indexes) {
      _indexesTree.remove(i);
    }

    _layouts!.remove(id);
    notifyListeners();
  }

  void _scrollToY(int y, Duration duration, Curve curve) {
    final lastY = _layouts![_endsTree[_endsTree.lastKey()]];

    if (lastY != null) {
      final lastH = ((lastY.height + lastY.startY) * verticalSlotEdge) - _viewportDelegate.constraints.maxHeight;
      if (y > lastH) {
        y = lastH.toInt();
      }
    }

    if (scrollToAdded) {
      if (duration != Duration.zero) {
        _viewportOffset.animateTo(y * slotEdge, duration: duration, curve: curve);
      } else {
        _viewportOffset.jumpTo(y * slotEdge);
      }
    }
  }

  void add(
    DashboardItem item, {
    bool mountToTop = true,
    required Duration duration,
    required Curve curve,
  }) {
    _layouts![item.identifier] = _ItemCurrentLayout(item.layoutData);
    this.mountToTop(item.identifier, mountToTop ? 0 : getIndex([_adjustToPosition(item.layoutData), item.layoutData.startY]));

    // Track items added during edit mode
    if (_isEditing) {
      _itemsAddedDuringEdit.add(item.identifier);
    }

    notifyListeners();

    // TODO: scroll to item
    _scrollToY(_layouts![item.identifier]!.startY, duration, curve);
  }

  int _adjustToPosition(ItemLayout layout) {
    int start;
    if (layout.startX + layout.width > slotCount) {
      start = slotCount - layout.width;
    } else {
      start = layout.startX;
    }
    return start;
  }

  void addAll(List<DashboardItem> items, {bool mountToTop = true}) {
    for (var item in items) {
      _layouts![item.identifier] = _ItemCurrentLayout(item.layoutData);

      int startX;

      if (mountToTop) {
        startX = 0;
      } else {
        startX = _adjustToPosition(item.layoutData);
      }

      int startY = item.layoutData.startY;

      this.mountToTop(item.identifier, getIndex([startX, startY]));

      // Track items added during edit mode
      if (_isEditing) {
        _itemsAddedDuringEdit.add(item.identifier);
      }
    }
    notifyListeners();
  }

  ///
  List<int> getIndexCoordinate(int index) {
    return [index % slotCount, index ~/ slotCount];
  }

  List<int?> getOverflowsAlt(ItemLayout itemLayout) {
    var possibilities = <_OverflowPossibility>[];

    var y = itemLayout.startY;
    var eY = itemLayout.startY + itemLayout.height;
    var eX = min(itemLayout.startX + itemLayout.width, slotCount + 1);

    var minX = eX;

    yLoop:
    while (y < eY) {
      var x = itemLayout.startX;
      xLoop:
      while (x < eX) {
        if (x > minX) {
          possibilities.add(_OverflowPossibility(x, y + 1, x - itemLayout.startX, y - itemLayout.startY + 1));
          break xLoop;
        }
        if (_indexesTree.containsKey(getIndex([x, y]))) {
          minX = x - 1;
          // filled
          if (x == itemLayout.startX) {
            if (y == itemLayout.startY) {
              return [x, y];
            } else {
              if (possibilities.isEmpty) {
                return [null, y];
              }

              possibilities.removeWhere((element) {
                return (element.w < itemLayout.minWidth || element.h < itemLayout.minHeight);
              });

              if (possibilities.isEmpty) {
                return [itemLayout.startX, itemLayout.startY];
              }

              possibilities.sort((a, b) => b.compareTo(a));

              var p = possibilities.first;

              return [p.x, p.y];
            }
          }

          if (possibilities.isEmpty) {
            possibilities.add(_OverflowPossibility(itemLayout.startX + itemLayout.width, y, itemLayout.width, y - itemLayout.startY));
          }

          possibilities.add(_OverflowPossibility(x, y + 1, x - itemLayout.startX, y - itemLayout.startY + 1));

          y++;
          continue yLoop;
        }
        x++;
      }
      y++;
    }

    if (possibilities.isEmpty) {
      return [null, null];
    }

    possibilities.removeWhere((element) {
      return (element.w < itemLayout.minWidth || element.h < itemLayout.minHeight);
    });

    if (possibilities.isEmpty) {
      return [itemLayout.startX, itemLayout.startY];
    }

    possibilities.sort((a, b) {
      return b.compareTo(a);
    });

    var p = possibilities.first;

    return [p.x, p.y];
  }

  void _removeFromIndexes(ItemLayout itemLayout, String id) {
    var i = getItemIndexes(itemLayout);
    if (i.isEmpty) return;
    var ss = _startsTree.containsKey(i.first);
    if (ss && _startsTree[i.first] == id) {
      _startsTree.remove((i.first));
    }

    var es = _endsTree.containsKey(i.last);
    if (es && _endsTree[i.last] == id) {
      _endsTree.remove((i.last));
    }
    for (var index in i) {
      var s = _indexesTree[index];
      if (s != null && s == id) {
        _indexesTree.remove(index);
      }
    }
  }

  void _reIndexItem(ItemLayout itemLayout, String id) {
    var l = _layouts![id]!;
    _removeFromIndexes(l.origin, id);
    l._height = null;
    l._width = null;
    l._startX = null;
    l._startY = null;
    _indexItem(itemLayout, id);
  }

  void _indexItem(ItemLayout itemLayout, String id) {
    var i = getItemIndexes(itemLayout);
    if (i.isEmpty) throw Exception("I don't understand: $id : $itemLayout");
    _startsTree[i.first] = id;
    _endsTree[i.last] = id;
    for (var index in i) {
      _indexesTree[index] = id;
    }

    _layouts![id]!.origin = itemLayout.._haveLocation = true;
    _layouts![id]!._mount(this, id);
  }

  bool? shrinkOnMove;

  /// Finds all items that conflict with the specified layout
  List<String> findConflictingItems(ItemLayout layout) {
    List<String> conflictingItems = [];
    Set<String> uniqueIds = {};

    // Pour chaque position occupée par le nouveau layout
    for (var y = layout.startY; y < layout.startY + layout.height; y++) {
      for (var x = layout.startX; x < layout.startX + layout.width; x++) {
        // Si x est hors limite horizontale, ignorer
        if (x >= slotCount) continue;

        // Vérifier si cette position est déjà occupée
        int index = getIndex([x, y]);
        String? existingItemId = _indexesTree[index];

        // Si la position est occupée et que ce n'est pas par l'élément actuel
        if (existingItemId != null && !uniqueIds.contains(existingItemId)) {
          uniqueIds.add(existingItemId);
          conflictingItems.add(existingItemId);
        }
      }
    }

    return conflictingItems;
  }

  /// Déterminer la zone visée dans une case occupée
  DropZone determineDropZone(Offset relativePosition) {
    final relativeX = relativePosition.dx;
    final relativeY = relativePosition.dy;

    const threshold = 0.25; // 25% des bords considérés comme zones spéciales

    if (relativeY < threshold) return DropZone.top;
    if (relativeY > 1 - threshold) return DropZone.bottom;
    if (relativeX < threshold) return DropZone.left;
    if (relativeX > 1 - threshold) return DropZone.right;

    return DropZone.center;
  }

  /// Trouve la position relative dans un élément à partir d'un offset absolu
  Offset getRelativePosition(Offset holdOffset, String targetItemId) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return const Offset(0.5, 0.5); // Centre par défaut

    // Calculer la position de l'élément dans l'espace absolu
    double left = targetItem.startX * slotEdge;
    double top = targetItem.startY * verticalSlotEdge;
    double width = targetItem.width * slotEdge;
    double height = targetItem.height * verticalSlotEdge;

    // Calculer la position relative
    return Offset((holdOffset.dx - left) / width, (holdOffset.dy - top) / height);
  }

  /// Pushes conflicting items down to make room for the specified layout
  bool pushItems(String itemId, ItemLayout layout, {Offset? holdOffset, String? targetItemId}) {
    // Si nous avons une position de curseur et un élément cible, utiliser la détection de zone
    if (holdOffset != null && targetItemId != null && targetItemId != itemId) {
      // Déterminer la zone visée dans l'élément cible
      Offset relativePosition = getRelativePosition(holdOffset, targetItemId);
      DropZone dropZone = determineDropZone(relativePosition);

      // Appliquer une stratégie spécifique selon la zone
      return pushItemsWithZone(itemId, layout, targetItemId, dropZone);
    }

    // Comportement par défaut (pousser vers le bas)
    return pushItemsDown(itemId, layout);
  }

  /// Déplace les éléments en fonction de la zone ciblée
  bool pushItemsWithZone(String itemId, ItemLayout layout, String targetItemId, DropZone dropZone) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return false;

    switch (dropZone) {
      case DropZone.top:
        // Insérer au-dessus de l'élément cible
        return insertAboveItem(itemId, layout, targetItemId);
      case DropZone.bottom:
        // Insérer en-dessous de l'élément cible
        return insertBelowItem(itemId, layout, targetItemId);
      case DropZone.left:
        // Essayer d'insérer à gauche si l'espace le permet
        return insertLeftOfItem(itemId, layout, targetItemId);
      case DropZone.right:
        // Essayer d'insérer à droite si l'espace le permet
        return insertRightOfItem(itemId, layout, targetItemId);
      case DropZone.center:
      default:
        // Comportement normal: pousser vers le bas
        return pushItemsDown(itemId, layout);
    }
  }

  /// Insère un élément au-dessus d'un autre
  bool insertAboveItem(String itemId, ItemLayout layout, String targetItemId) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return false;

    // Créer un nouveau layout avec Y positionné juste au-dessus de l'élément cible
    var newLayout = layout.copyWithStarts(startX: layout.startX, startY: targetItem.startY - layout.height);

    // Si le nouvel Y est négatif, placer à 0 et pousser les autres éléments
    if (newLayout.startY < 0) {
      newLayout = newLayout.copyWithStarts(startY: 0);

      // Pousser tous les éléments en conflit avec ce nouvel emplacement
      List<String> conflictingItems = findConflictingItems(newLayout);
      if (conflictingItems.isEmpty) {
        _indexItem(newLayout, itemId);
        return true;
      }

      // Déplacer tous les éléments en conflit vers le bas
      int verticalShift = layout.height;
      return moveItemsVertically(conflictingItems, verticalShift, itemId, newLayout);
    } else {
      // Vérifier s'il y a des conflits à cette nouvelle position
      List<String> conflictingItems = findConflictingItems(newLayout);
      if (conflictingItems.isEmpty) {
        _indexItem(newLayout, itemId);
        return true;
      }

      // S'il y a des conflits, essayer de pousser ces éléments vers le haut
      int verticalShift = -layout.height;
      return moveItemsVertically(conflictingItems, verticalShift, itemId, newLayout);
    }
  }

  /// Insère un élément en-dessous d'un autre
  bool insertBelowItem(String itemId, ItemLayout layout, String targetItemId) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return false;

    // Créer un nouveau layout avec Y positionné juste en-dessous de l'élément cible
    var newLayout = layout.copyWithStarts(startX: layout.startX, startY: targetItem.startY + targetItem.height);

    // Vérifier s'il y a des conflits à cette nouvelle position
    List<String> conflictingItems = findConflictingItems(newLayout);
    if (conflictingItems.isEmpty) {
      _indexItem(newLayout, itemId);
      return true;
    }

    // S'il y a des conflits, pousser ces éléments vers le bas
    int verticalShift = layout.height;
    return moveItemsVertically(conflictingItems, verticalShift, itemId, newLayout);
  }

  /// Insère un élément à gauche d'un autre si l'espace le permet
  bool insertLeftOfItem(String itemId, ItemLayout layout, String targetItemId) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return false;

    // Vérifier si l'espace à gauche est suffisant
    if (targetItem.startX < layout.width) {
      // Pas assez d'espace à gauche, essayer en-dessous
      return insertBelowItem(itemId, layout, targetItemId);
    }

    // Créer un nouveau layout positionné à gauche de l'élément cible
    var newLayout = layout.copyWithStarts(startX: targetItem.startX - layout.width, startY: targetItem.startY);

    // Vérifier s'il y a des conflits à cette nouvelle position
    List<String> conflictingItems = findConflictingItems(newLayout);
    if (conflictingItems.isEmpty) {
      _indexItem(newLayout, itemId);
      return true;
    }

    // S'il y a des conflits, essayer plutôt en-dessous
    return insertBelowItem(itemId, layout, targetItemId);
  }

  /// Insère un élément à droite d'un autre si l'espace le permet
  bool insertRightOfItem(String itemId, ItemLayout layout, String targetItemId) {
    var targetItem = _layouts![targetItemId];
    if (targetItem == null) return false;

    // Vérifier si l'espace à droite est suffisant
    if (targetItem.startX + targetItem.width + layout.width > slotCount) {
      // Pas assez d'espace à droite, essayer en-dessous
      return insertBelowItem(itemId, layout, targetItemId);
    }

    // Créer un nouveau layout positionné à droite de l'élément cible
    var newLayout = layout.copyWithStarts(startX: targetItem.startX + targetItem.width, startY: targetItem.startY);

    // Vérifier s'il y a des conflits à cette nouvelle position
    List<String> conflictingItems = findConflictingItems(newLayout);
    if (conflictingItems.isEmpty) {
      _indexItem(newLayout, itemId);
      return true;
    }

    // S'il y a des conflits, essayer plutôt en-dessous
    return insertBelowItem(itemId, layout, targetItemId);
  }

  /// Déplace une liste d'éléments verticalement et place l'élément courant
  bool moveItemsVertically(List<String> itemIds, int verticalShift, String currentItemId, ItemLayout currentLayout) {
    // Mémoriser les positions actuelles pour pouvoir les restaurer en cas d'échec
    Map<String, ItemLayout> originalLayouts = {};
    for (var id in itemIds) {
      var item = _layouts![id];
      if (item != null) {
        originalLayouts[id] = item.origin;
      }
    }

    // Supprimer temporairement les éléments en conflit des index
    for (var id in itemIds) {
      var item = _layouts![id];
      if (item != null) {
        _removeFromIndexes(item.origin, id);
      }
    }

    // Placer l'élément courant
    _indexItem(currentLayout, currentItemId);

    // Repositionner les éléments en conflit
    bool allPlaced = true;
    for (var id in itemIds) {
      var item = _layouts![id];
      if (item == null) continue;

      var newLayout = item.origin.copyWithStarts(startX: item.startX, startY: item.startY + verticalShift);

      var success = tryPushAndMount(id, newLayout);
      if (!success) {
        allPlaced = false;
        break;
      }
    }

    if (!allPlaced) {
      // Si un placement a échoué, restaurer les positions d'origine
      _removeFromIndexes(currentLayout, currentItemId);

      for (var entry in originalLayouts.entries) {
        if (_layouts!.containsKey(entry.key)) {
          _indexItem(entry.value, entry.key);
        }
      }

      return false;
    }

    return true;
  }

  /// Méthode originale renommée pour pousser tous les éléments vers le bas
  bool pushItemsDown(String itemId, ItemLayout layout) {
    // Trouver les éléments en conflit
    List<String> conflictingItems = findConflictingItems(layout);
    if (conflictingItems.isEmpty) return true;

    // Calcul du déplacement vertical nécessaire (hauteur de l'élément à placer)
    int verticalShift = layout.height;

    // Pour chaque élément en conflit, déplacer vers le bas
    for (var conflictId in conflictingItems) {
      var conflictItem = _layouts![conflictId];
      if (conflictItem == null) continue;

      // Créer un nouveau layout avec position Y augmentée
      var newLayout = conflictItem.origin.copyWithStarts(startX: conflictItem.startX, startY: conflictItem.startY + verticalShift);

      // Supprimer l'élément de sa position actuelle
      _removeFromIndexes(conflictItem.origin, conflictId);

      // Essayer de placer l'élément à sa nouvelle position
      // Si d'autres éléments sont en conflit, ils seront également déplacés récursivement
      var success = tryPushAndMount(conflictId, newLayout);
      if (!success) {
        // Si le déplacement échoue, remettre tous les éléments en place et annuler
        mountItems(); // Réinitialiser la disposition
        return false;
      }
    }

    return true;
  }

  /// Attempts to mount an item at a specific position, pushing other items if necessary
  bool tryPushAndMount(String id, ItemLayout layout) {
    // Vérifier si le layout dépasse des limites horizontales
    if (layout.startX + layout.width > slotCount) {
      if (layout.minWidth < layout.width) {
        // Réduire la largeur si possible
        var newLayout = layout.copyWithDimension(width: slotCount - layout.startX);
        return tryPushAndMount(id, newLayout);
      } else {
        return false; // Impossible de placer l'élément
      }
    }

    // Trouver les éléments en conflit
    List<String> conflictingItems = findConflictingItems(layout);

    if (conflictingItems.isEmpty) {
      // Aucun conflit, placer directement
      _indexItem(layout, id);
      return true;
    } else {
      // Déplacer les éléments en conflit
      int verticalShift = layout.height;

      // Mémoriser les positions actuelles pour pouvoir les restaurer en cas d'échec
      Map<String, ItemLayout> originalLayouts = {};
      for (var conflictId in conflictingItems) {
        var conflictItem = _layouts![conflictId];
        if (conflictItem != null) {
          originalLayouts[conflictId] = conflictItem.origin;
        }
      }

      // Supprimer temporairement les éléments en conflit des index
      for (var conflictId in conflictingItems) {
        var conflictItem = _layouts![conflictId];
        if (conflictItem != null) {
          _removeFromIndexes(conflictItem.origin, conflictId);
        }
      }

      // Placer l'élément courant
      _indexItem(layout, id);

      // Repositionner les éléments en conflit
      bool allPlaced = true;
      for (var conflictId in conflictingItems) {
        var conflictItem = _layouts![conflictId];
        if (conflictItem == null) continue;

        var newLayout = conflictItem.origin.copyWithStarts(startX: conflictItem.startX, startY: conflictItem.startY + verticalShift);

        var success = tryPushAndMount(conflictId, newLayout);
        if (!success) {
          allPlaced = false;
          break;
        }
      }

      if (!allPlaced) {
        // Si un placement a échoué, restaurer les positions d'origine
        _removeFromIndexes(layout, id);

        for (var entry in originalLayouts.entries) {
          if (_layouts!.containsKey(entry.key)) {
            _indexItem(entry.value, entry.key);
          }
        }

        return false;
      }

      return true;
    }
  }

  ///
  ItemLayout? tryMount(int value, ItemLayout itemLayout) {
    var shrinkToPlaceL = shrinkOnMove ?? shrinkToPlace;

    var r = getIndexCoordinate(value);
    var n = itemLayout.copyWithStarts(startX: r[0], startY: r[1]);
    var i = 0;
    while (true) {
      if (i > 1000000) {
        throw Exception("loop");
      }
      i++;

      var exOut = n.startX + n.width > slotCount;

      if (exOut && !shrinkToPlaceL) {
        return null;
      }

      if (shrinkToPlaceL && exOut) {
        // Not fit to viewport
        if (n.minWidth < n.width) {
          n = n.copyWithDimension(width: n.width - 1);
          continue;
        } else {
          return null;
        }
      } else {
        // Fit viewport
        var overflows = getOverflowsAlt(n);
        if (overflows.where((element) => element != null).isEmpty) {
          // both null
          return n;
        } else {
          if (shrinkToPlaceL) {
            var eX = overflows[0] ?? (n.startX + n.width);
            var eY = overflows[1] ?? (n.startY + n.height);

            if (eX - n.startX >= n.minWidth && eY - n.startY >= n.minHeight) {
              return n.copyWithDimension(width: eX - n.startX, height: eY - n.startY);
            } else {
              return null;
            }
          } else {
            return null;
          }
        }
      }
    }
  }

  ///
  bool mountToTop(String id, [int start = 0]) {
    try {
      var itemCurrent = _layouts![id]!;

      _removeFromIndexes(itemCurrent, id);

      var i = start;
      while (true) {
        var nLayout = tryMount(i, itemCurrent.origin);
        if (nLayout != null) {
          _indexItem(nLayout, id);
          return true;
        }

        if (i > 1000000) {
          throw Exception("Stack overflow");
        }
        i++;
      }
    } on Exception {
      rethrow;
    }
  }

  ///
  void _slideToTopAll() {
    var l = _startsTree.values.toList();

    _startsTree.clear();
    _endsTree.clear();
    _indexesTree.clear();
    for (var e in l) {
      mountToTop(e);
    }
  }

  ///
  void mountItems() {
    try {
      if (!_isAttached) throw Exception("Not Attached");

      _startsTree.clear();
      _endsTree.clear();
      _indexesTree.clear();

      var not = <String>[];

      layouts:
      for (var i in _layouts!.entries.where((element) => element.value._haveLocation)) {
        if (_axis == Axis.vertical && i.value.width > slotCount) {
          // Check fit, if necessary and possible, edit
          if (i.value.minWidth > slotCount) {
            throw Exception("Minimum width > slotCount");
          } else {
            if (!shrinkToPlace) {
              throw Exception("width not fit");
            }
          }
        }

        // can mount given start index
        var mount = tryMount(getIndex([i.value.startX, i.value.startY]), i.value.origin);

        if (mount == null) {
          not.add(i.key);
          continue layouts;
        }

        _indexItem(mount, i.key);
      }

      layouts:
      for (var i in _layouts!.entries.where((element) => !element.value._haveLocation)) {
        if (_axis == Axis.vertical && i.value.width > slotCount) {
          // Check fit, if necessary and possible, edit
          if (i.value.minWidth > slotCount) {
            throw Exception("Minimum width > slotCount");
          } else {
            if (!shrinkToPlace) {
              throw Exception("width not fit");
            }
          }
        }

        // can mount given start index
        var mount = tryMount(getIndex([i.value.startX, i.value.startY]), i.value.origin);

        if (mount == null) {
          not.add(i.key);
          continue layouts;
        }

        _indexItem(mount, i.key);
      }

      List<String> changes = [];

      if (slideToTop) {
        _slideToTopAll();
        changes.addAll(_startsTree.values);
      }

      for (var n in not) {
        mountToTop(n);
      }

      changes.addAll(not);

      if (changes.isNotEmpty) {
        itemController.itemStorageDelegate?._onItemsUpdated(changes.map((e) => itemController._getItemWithLayout(e)).toList(), slotCount);
      }
    } on Exception {
      rethrow;
    }
  }

  ///
  int getIndex(List<int> point) {
    var x = point[0];
    var y = point[1];
    return (y * slotCount) + x;
  }

  ///
  BoxConstraints getConstrains(ItemLayout layout) {
    return BoxConstraints(maxHeight: layout.height * verticalSlotEdge, maxWidth: layout.width * slotEdge);
  }

  ///
  List<int> getItemIndexes(ItemLayout data) {
    if (!_isAttached) throw Exception("Not Attached");
    var l = <int>[];

    var y = data.startY;
    var eY = data.startY + data.height;
    var eX = data.startX + data.width;

    if (data.startY < 0 || data.startX >= slotCount || eX > slotCount) {
      return [];
    }

    while (y < eY) {
      var x = data.startX;
      xLoop:
      while (x < eX) {
        if (x >= slotCount) {
          continue xLoop;
        }
        l.add(getIndex([x, y]));
        x++;
      }
      y++;
    }

    return l;
  }

  void _setSizes(BoxConstraints constrains, double vertical) {
    verticalSlotEdge = vertical;
    slotEdge = (_axis == Axis.vertical ? constrains.maxWidth : constrains.maxHeight) / slotCount;
  }

  late bool animateEverytime;

  late ViewportOffset _viewportOffset;

  ///
  void attach({
    required ViewportOffset viewportOffset,
    required bool shrinkToPlace,
    required bool slideToTop,
    required bool removeEmptyRows,
    required Axis axis,
    required DashboardItemController<T> itemController,
    required int slotCount,
    required bool animateEverytime,
    required bool scrollToAdded,
    bool? shrinkOnMove,
    bool? pushElementsOnConflict,
  }) {
    this.shrinkToPlace = shrinkToPlace;
    this.slideToTop = slideToTop;
    this.removeEmptyRows = removeEmptyRows;
    this.shrinkOnMove = shrinkOnMove;
    this._axis = axis;
    this.itemController = itemController;
    this.slotCount = slotCount;
    this._viewportOffset = viewportOffset;
    this.animateEverytime = animateEverytime;
    _isAttached = true;
    this.scrollToAdded = scrollToAdded;
    this.pushElementsOnConflict = pushElementsOnConflict ?? false;
    _layouts ??= <String, _ItemCurrentLayout>{};
    _layouts!.clear();

    var keys = itemController._items.values.map((e) => e.identifier).toList();
    keys.sort();

    for (var key in keys) {
      var item = itemController._items[key];
      _layouts![key] = _ItemCurrentLayout(item!.layoutData);
    }
    mountItems();
    _rebuild = true;
  }

  bool _rebuild = false;

  ///
  bool _isAttached = false;

  /// Confirms all pending changes and exits edit mode
  void confirmChanges() {
    if (_pendingChanges.isNotEmpty || _itemsAddedDuringEdit.isNotEmpty || _itemsDeletedDuringEdit.isNotEmpty) {
      // Persist all pending changes to storage
      if (itemController.itemStorageDelegate != null) {
        // Traiter les changements de position/taille
        var changedItems = _pendingChanges.where((id) => itemController._items.containsKey(id)).map((e) => itemController._getItemWithLayout(e)).toList();

        if (changedItems.isNotEmpty) {
          itemController.itemStorageDelegate!._onItemsUpdated(changedItems, slotCount);
        }

        // Traiter les ajouts d'éléments pendant l'édition
        if (_itemsAddedDuringEdit.isNotEmpty) {
          var addedItems =
              _itemsAddedDuringEdit.where((id) => itemController._items.containsKey(id)).map((id) => itemController._getItemWithLayout(id)).toList();

          if (addedItems.isNotEmpty) {
            itemController.itemStorageDelegate!._onItemsAdded(addedItems, slotCount);
          }
        }

        // Traiter les suppressions d'éléments pendant l'édition
        if (_itemsDeletedDuringEdit.isNotEmpty) {
          var deletedItems = _itemsDeletedDuringEdit.values.toList();

          if (deletedItems.isNotEmpty) {
            itemController.itemStorageDelegate!._onItemsDeleted(deletedItems, slotCount);
          }
        }

        // Clear deleted items as they are now confirmed deleted
        _itemsDeletedDuringEdit.clear();
        // Clear added items tracking as they are now confirmed
        _itemsAddedDuringEdit.clear();
      }

      // Apply compact layout if enabled
      if (removeEmptyRows) {
        compactLayout();
      }

      // Clear state
      _pendingChanges.clear();
      _initialLayouts = null;
      _initialItems = null;
    }

    _isEditing = false;
    notifyListeners();
  }

  /// Cancels all pending changes and reverts to the initial state
  void cancelChanges() {
    // If we have initial state saved
    if (_initialLayouts != null && _initialItems != null) {
      // Remove items that were added during edit mode
      for (var id in _itemsAddedDuringEdit) {
        if (_layouts!.containsKey(id)) {
          var l = _layouts![id];
          if (l != null) {
            var indexes = getItemIndexes(l.origin);
            _startsTree.remove(indexes.first);
            _endsTree.remove(indexes.last);

            for (var i in indexes) {
              _indexesTree.remove(i);
            }

            _layouts!.remove(id);
            itemController._items.remove(id);
          }
        }
      }

      // Restore items that were deleted during edit mode
      for (var entry in _itemsDeletedDuringEdit.entries) {
        itemController._items[entry.key] = entry.value;
      }

      // Reset indexes for reindexing
      _startsTree.clear();
      _endsTree.clear();
      _indexesTree.clear();

      // Restore original layouts
      for (var entry in _initialLayouts!.entries) {
        var id = entry.key;
        var originalLayout = entry.value;

        if (itemController._items.containsKey(id)) {
          // Restore layout for existing items
          if (_layouts!.containsKey(id)) {
            _layouts![id]!._height = null;
            _layouts![id]!._width = null;
            _layouts![id]!._startX = null;
            _layouts![id]!._startY = null;
          } else {
            // Create layout for restored items
            _layouts![id] = _ItemCurrentLayout(originalLayout);
          }
          _indexItem(originalLayout, id);
        }
      }

      // Clear state
      _pendingChanges.clear();
      _itemsAddedDuringEdit.clear();
      _itemsDeletedDuringEdit.clear();
      _initialLayouts = null;
      _initialItems = null;
    }

    _isEditing = false;
    notifyListeners();
  }

  void saveEditSession() {
    if (editSession == null) return;

    if (editSession!._changes.isNotEmpty) {
      // Instead of immediately updating storage, just mark these items as changed
      _pendingChanges.addAll(editSession!._changes);

      // Apply changes visually
      for (var i in editSession!._changes) {
        _layouts![i]!._clearListeners();
      }
    }

    // Simply finish the edit session without triggering confirmation
    editSession = null;
    notifyListeners();
  }
}

class _OverflowPossibility extends Comparable<_OverflowPossibility> {
  _OverflowPossibility(this.x, this.y, this.w, this.h) : sq = w * h;

  int x, y, w, h, sq;

  @override
  int compareTo(_OverflowPossibility other) {
    return sq.compareTo(other.sq);
  }
}

///
class _EditSession {
  ///
  _EditSession({required _DashboardLayoutController layoutController, required this.editing, required this.transform}) : editingOrigin = editing.copy();

  bool transform;

  ///
  bool get isEqual {
    return editing.startX == editingOrigin.startX &&
        editing.startY == editingOrigin.startY &&
        editing.width == editingOrigin.width &&
        editing.height == editingOrigin.height;
  }

  List<String> get _changes {
    var changes = <String>[];
    if (!isEqual) {
      for (var dir in _indirectChanges.entries) {
        var dirChanges = _indirectChanges[dir.key];
        if (dirChanges != null) {
          for (var ch in dirChanges.entries) {
            if (ch.value.isNotEmpty) {
              changes.add(ch.key);
            }
          }
        }
      }
      changes.add(editing.id);
    }

    return changes;
  }

  // final Map<AxisDirection, List<Resizing>> _resizes = {};

  final Map<AxisDirection, Map<String, List<_Change>>> _indirectChanges = {};

  final Map<String, _Swap> _swapChanges = {};

  void _addResize(_Resize resize, void Function(String id, _Change) onBackChange) {
    if (resize.resize.increment && resize.indirectResizes != null) {
      for (var indirect in resize.indirectResizes!.entries) {
        _indirectChanges[indirect.value.direction] ??= {};
        _indirectChanges[indirect.value.direction]![indirect.key] ??= [];
        _indirectChanges[indirect.value.direction]![indirect.key]!.add(indirect.value);
      }
    }

    if (!resize.resize.increment) {
      var dir = resize.resize.direction;
      AxisDirection reverseDir;
      if (dir == AxisDirection.left) {
        reverseDir = AxisDirection.right;
      } else if (dir == AxisDirection.right) {
        reverseDir = AxisDirection.left;
      } else if (dir == AxisDirection.up) {
        reverseDir = AxisDirection.down;
      } else {
        reverseDir = AxisDirection.up;
      }

      var reverseIndirectResizes = _indirectChanges[reverseDir];

      if (reverseIndirectResizes == null) {
        return;
      } else {
        for (var resize in reverseIndirectResizes.entries) {
          if (resize.value.isNotEmpty) {
            onBackChange(resize.key, resize.value.removeAt(resize.value.length - 1));
          }
        }
      }
    }
  }

  /*void _addSwap(
      String directId, String indirectId, _Swap direct, _Swap indirect) {
    _swapChanges[directId] = direct;
    _swapChanges[indirectId] = indirect;
  }*/

  ///
  final _ItemCurrentLayout editing;

  ///
  final _ItemCurrentLayout editingOrigin;
}
