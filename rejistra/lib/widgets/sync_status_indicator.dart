import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:rejistra/providers/data_provider.dart';

class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dataProvider = context.watch<DataProvider>();

    if (dataProvider.pendingSyncCount == 0) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sync, size: 16, color: Colors.orange.shade800),
          SizedBox(width: 6),
          Text(
            '${dataProvider.pendingSyncCount} en attente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}