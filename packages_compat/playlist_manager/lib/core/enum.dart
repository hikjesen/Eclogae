enum PlaylistAddDuplicateAction {
  justAddEverything,
  addAllAndRemoveOldOnes,
  addOnlyMissing,
  mergeAndSortByAddedDate,
  deleteAndCreateNewPlaylist;

  static const valuesForAdd = [
    justAddEverything,
    addAllAndRemoveOldOnes,
    addOnlyMissing,
  ];

  static const valuesForAddExcludingAddEverything = [
    addAllAndRemoveOldOnes,
    addOnlyMissing,
  ];
}
