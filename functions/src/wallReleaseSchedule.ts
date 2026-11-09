import {onSchedule} from "firebase-functions/v2/scheduler";
import {REGION} from "./common";
import {drainReleaseNotices} from "./onWallApproved";
import {releaseDueWalls} from "./wallRelease";

export const releaseScheduledWalls = onSchedule(
  {schedule: "*/5 * * * *", region: REGION, timeZone: "UTC", retryCount: 2},
  async () => {
    try {
      await releaseDueWalls(Date.now());
    } finally {
      await drainReleaseNotices();
    }
  },
);
