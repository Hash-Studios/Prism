import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:prism/model/setup/setup_model.dart';
import 'package:prism/model/wallhaven/wallhaven_wall_model.dart';
import 'package:prism/services/logger.dart';
import 'package:timeago/timeago.dart' as timeago;

class SetupCard extends StatelessWidget {
  const SetupCard({
    Key? key,
    required this.snapshot,
    required this.index,
  }) : super(key: key);

  final AsyncSnapshot<List<Setup>> snapshot;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 80,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () {
                logger.d('Tapped on ${snapshot.data?[index].image}');
              },
              child: Container(
                color: Theme.of(context).primaryColor.withOpacity(0.2),
                child: CachedNetworkImage(
                  imageUrl: snapshot.data?[index].image ?? '',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timeago.format(
                      snapshot.data?[index].createdAt ?? DateTime.now(),
                      allowFromNow: true),
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .caption
                      ?.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  child: Container(
                    color: Colors.transparent,
                    child: Icon(
                      Icons.more_horiz,
                      color: Theme.of(context).textTheme.caption?.color,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
