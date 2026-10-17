import 'package:Prism/core/firestore/firestore_document.dart';

/// Only unreviewed Studio walls can go to the weekly Drop.
bool canReserveForDrop(FirestoreDocument wall) => wall.payload['origin'] == 'studio' && !wall.review;

/// The planner sets `dropWeek` when it puts a wall in a Drop. Those walls leave the review queue.
bool isInDrop(FirestoreDocument wall) => wall.payload['dropWeek'] != null;
