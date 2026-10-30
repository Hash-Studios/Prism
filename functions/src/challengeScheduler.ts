import {onSchedule} from "firebase-functions/v2/scheduler";
import {REGION} from "./common";
import {r2Secrets} from "./r2Storage";
import {publishedChallengeAwardNeedsRefresh, runChallengeLifecycle} from "./weeklyChallenges";
import {pickWallOfTheDay} from "./wallOfTheDay";

export async function refreshPublishedChallengeAward(now: number): Promise<void> {
  if (await publishedChallengeAwardNeedsRefresh(now)) await pickWallOfTheDay(now);
}

export async function runChallengeSchedule(slot: number, now?: number): Promise<void> {
  await runChallengeLifecycle(slot, refreshPublishedChallengeAward, now);
}

export const scheduleWeeklyChallenges = onSchedule({schedule: "*/15 * * * *", timeZone: "UTC", region: REGION,
  retryCount: 3, secrets: r2Secrets}, async (event) => runChallengeSchedule(Date.parse(event.scheduleTime)));
