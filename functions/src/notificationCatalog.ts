/** English notification copy is the compatibility fallback for old clients and unsupported locales. */
export type NotificationCopy =
  | { kind: "wallApprovedForArtist"; wallTitle: string }
  | { kind: "wallLiveForFollowers"; artistName: string; wallTitle: string }
  | { kind: "wallApprovedForAdmin"; wallTitle: string; artistName: string }
  | { kind: "newFollower"; followerName: string }
  | { kind: "streakReminder" }
  | { kind: "wotdForCreator" }
  | { kind: "wotdForAudience"; wallTitle: string }
  | { kind: "winBack7" }
  | { kind: "winBack14" }
  | { kind: "winBack30" }
  | { kind: "winBack60" }
  | { kind: "dropLive"; wallCount: number }
  | { kind: "dropLastCall"; dropTitle: string; hoursLeft: number }
  | { kind: "galleryDrop"; wallCount: number; tags: string }
  | {
      kind: "followDigest";
      artistName: string;
      secondArtistName: string;
      creatorCount: number;
      wallCount: number;
      tags: string;
    }
  | { kind: "folderDigest"; folderName: string; folderCount: number; wallCount: number; tags: string }
  | { kind: "drawWinner" }
  | { kind: "giftReceived"; senderName: string }
  | { kind: "reportNeedsReview"; contentType: string; reason: string }
  | {
      kind: "newContentReport";
      contentType: string;
      reason: string;
      targetId: string;
    }
  | { kind: "wallSubmittedForReview"; artistName: string; artistEmail: string }
  | { kind: "custom"; title: string; body: string };

export interface RenderedNotificationCopy {
  kind: NotificationCopy["kind"];
  args: Record<string, string | number>;
  title: string;
  body: string;
}

export interface NativeNotificationLocalization {
  titleKey: string;
  titleArgs: string[];
  bodyKey: string;
  bodyArgs: string[];
}

export const NATIVE_LOCALIZATION_TOPIC_SUFFIX = "_loc_v1";

export function nativeLocalizationTopic(topic: string): string {
  return topic.endsWith(NATIVE_LOCALIZATION_TOPIC_SUFFIX) ?
    topic :
    `${topic}${NATIVE_LOCALIZATION_TOPIC_SUFFIX}`;
}

export function isNativeLocalizationTopic(topic: string): boolean {
  return topic.endsWith(NATIVE_LOCALIZATION_TOPIC_SUFFIX);
}

/** Renders server-owned notification copy. User-authored names and titles are passed as arguments. */
export function renderNotificationCopy(
  copy: NotificationCopy,
): RenderedNotificationCopy {
  switch (copy.kind) {
  case "wallApprovedForArtist":
    return {
      kind: copy.kind,
      args: {wallTitle: copy.wallTitle},
      title: "Your wallpaper is live! 🎉",
      body: copy.wallTitle ?
        `"${copy.wallTitle}" has been approved and is now visible to everyone.` :
        "Your wallpaper has been approved and is now visible to everyone.",
    };
  case "wallLiveForFollowers":
    return {
      kind: copy.kind,
      args: {artistName: copy.artistName, wallTitle: copy.wallTitle},
      title: `New wall by ${copy.artistName}`,
      body: `"${copy.wallTitle}" is now live on Prism.`,
    };
  case "wallApprovedForAdmin":
    return {
      kind: copy.kind,
      args: {wallTitle: copy.wallTitle, artistName: copy.artistName},
      title: "Wall approved ✅",
      body: `"${copy.wallTitle}" by ${copy.artistName} is now live.`,
    };
  case "newFollower":
    return {
      kind: copy.kind,
      args: {followerName: copy.followerName},
      title: "You have a new follower! 🎉",
      body: `${copy.followerName} is now following you.`,
    };
  case "streakReminder":
    return {
      kind: copy.kind,
      args: {},
      title: "Your streak is about to break!",
      body: "Open Prism now to keep your login streak alive 🔥",
    };
  case "wotdForCreator":
    return {
      kind: copy.kind,
      args: {},
      title: "Your wallpaper is the Wall of the Day",
      body: "Prism picked your wallpaper for everyone today. Thank you for sharing it.",
    };
  case "wotdForAudience":
    return {
      kind: copy.kind,
      args: {wallTitle: copy.wallTitle},
      title: "Today's Wall of the Day is here",
      body: copy.wallTitle || "Open Prism to see today's Wall of the Day.",
    };
  case "winBack7":
    return {
      kind: copy.kind,
      args: {},
      title: "Your feed has new walls",
      body: "Fresh wallpapers landed while you were away.",
    };
  case "winBack14":
    return {
      kind: copy.kind,
      args: {},
      title: "New walls are waiting",
      body: "Come see what creators added this fortnight.",
    };
  case "winBack30":
    return {
      kind: copy.kind,
      args: {},
      title: "New AI styles to try",
      body: "Make a wallpaper that feels like you.",
    };
  case "winBack60":
    return {
      kind: copy.kind,
      args: {},
      title: "Prism misses you",
      body: "Your next favourite wall is a tap away.",
    };
  case "dropLive":
    return {
      kind: copy.kind,
      args: {wallCount: copy.wallCount},
      title: "A new Drop is live",
      body:
          copy.wallCount === 1 ?
            "1 wall, this week only. Preview it before it is gone." :
            `${copy.wallCount} walls, this week only. Preview them before they are gone.`,
    };
  case "dropLastCall":
    return {
      kind: copy.kind,
      args: {dropTitle: copy.dropTitle, hoursLeft: copy.hoursLeft},
      title: "Last call on this week's Drop",
      body: `${copy.dropTitle} ends in ${copy.hoursLeft} ${copy.hoursLeft === 1 ? "hour" : "hours"}. Then these walls are gone for a month.`,
    };
  case "galleryDrop": {
    const live = renderNotificationCopy({kind: "dropLive", wallCount: copy.wallCount});
    return {
      kind: copy.kind,
      args: {wallCount: copy.wallCount, tags: copy.tags},
      title: live.title,
      body: copy.tags || live.body,
    };
  }
  case "followDigest":
    return {
      kind: copy.kind,
      args: {
        artistName: copy.artistName,
        secondArtistName: copy.secondArtistName,
        creatorCount: copy.creatorCount,
        wallCount: copy.wallCount,
        tags: copy.tags,
      },
      title: followDigestTitle(copy),
      body: copy.tags || "Tap to see them all.",
    };
  case "folderDigest":
    return {
      kind: copy.kind,
      args: {folderName: copy.folderName, folderCount: copy.folderCount, wallCount: copy.wallCount, tags: copy.tags},
      title: copy.folderCount > 1 ? `New in ${copy.folderName} and ${copy.folderCount - 1} more` :
        `New in ${copy.folderName}`,
      body: copy.tags || "Tap to see them all.",
    };
  case "drawWinner":
    return {
      kind: copy.kind,
      args: {},
      title: "You won the Prism Draw",
      body: "One month of Pro and the Prism frame are yours.",
    };
  case "giftReceived":
    return {
      kind: copy.kind,
      args: {senderName: copy.senderName},
      title: `${copy.senderName} sent you a 24-hour Pro pass`,
      body: "Premium collections and premium walls are open until tomorrow.",
    };
  case "reportNeedsReview":
    return {
      kind: copy.kind,
      args: {contentType: copy.contentType, reason: copy.reason},
      title: "Report waiting for review",
      body: "A content report has been waiting for review for over 12 hours.",
    };
  case "newContentReport":
    return {
      kind: copy.kind,
      args: {
        contentType: copy.contentType,
        reason: copy.reason,
        targetId: copy.targetId,
      },
      title: "New content report",
      body: "A new content report is ready for review.",
    };
  case "wallSubmittedForReview":
    return {
      kind: copy.kind,
      args: {artistName: copy.artistName, artistEmail: copy.artistEmail},
      title: "New Premium Wall for review! 🎉",
      body: `New post by ${copy.artistName} (${copy.artistEmail}) is up for review.`,
    };
  case "custom":
    return {kind: copy.kind, args: {}, title: copy.title, body: copy.body};
  default: {
    const exhaustive: never = copy;
    return exhaustive;
  }
  }
}

type FollowDigestShape = "one" | "solo" | "pair" | "group";

/** One creator and one wall, one creator, two creators, or more. Native resources have no plurals, so each is a key. */
export function followDigestShape(creatorCount: number, wallCount: number): FollowDigestShape {
  if (creatorCount <= 1) return wallCount <= 1 ? "one" : "solo";
  return creatorCount === 2 ? "pair" : "group";
}

function followDigestTitle(copy: Extract<NotificationCopy, {kind: "followDigest"}>): string {
  switch (followDigestShape(copy.creatorCount, copy.wallCount)) {
  case "one":
    return `${copy.artistName} posted a new wall`;
  case "solo":
    return `${copy.artistName} posted ${copy.wallCount} new walls`;
  case "pair":
    return `${copy.artistName} and ${copy.secondArtistName} posted ${copy.wallCount} new walls`;
  case "group":
    return `${copy.artistName} and ${copy.creatorCount - 1} others posted ${copy.wallCount} new walls`;
  }
}

export function notificationCopyPayload(copy: NotificationCopy): {
  title: string;
  body: string;
  message: RenderedNotificationCopy;
} {
  const message = renderNotificationCopy(copy);
  return {title: message.title, body: message.body, message};
}

/** Native resource keys let Android and iOS localize background system banners by device locale. */
export function nativeNotificationLocalization(
  message: Pick<RenderedNotificationCopy, "kind" | "args">,
): NativeNotificationLocalization | null {
  const kind = message.kind;
  if (kind === "custom") return null;

  const prefix = `notif_push_${kind.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`)}`;
  const stringArg = (key: string): string => String(message.args[key] ?? "");
  let titleArgs: string[] = [];
  let bodyArgs: string[] = [];
  let titleSuffix = "";
  let bodySuffix = "";
  const tagsBody = () => {
    if (!stringArg("tags")) bodySuffix = "_untitled";
    else bodyArgs = [stringArg("tags")];
  };

  switch (kind) {
  case "wallLiveForFollowers":
    titleArgs.push(stringArg("artistName"));
    bodyArgs = [stringArg("wallTitle")];
    break;
  case "wallApprovedForArtist":
    if (!stringArg("wallTitle")) bodySuffix = "_untitled";
    else bodyArgs = [stringArg("wallTitle")];
    break;
  case "wotdForAudience":
    if (!stringArg("wallTitle")) bodySuffix = "_untitled";
    else bodyArgs = [stringArg("wallTitle")];
    break;
  case "wallApprovedForAdmin":
    bodyArgs = [stringArg("wallTitle"), stringArg("artistName")];
    break;
  case "newFollower":
    bodyArgs = [stringArg("followerName")];
    break;
  case "dropLive": {
    bodyArgs = [String(Number(message.args.wallCount ?? 0))];
    break;
  }
  case "dropLastCall": {
    bodyArgs = [
      stringArg("dropTitle"),
      String(Number(message.args.hoursLeft ?? 0)),
    ];
    break;
  }
  case "giftReceived":
    titleArgs.push(stringArg("senderName"));
    break;
  case "galleryDrop":
    // Topic pushes reach builds that predate this kind, so it uses only shipped resources: the Drop title, and the
    // pass-through body of the Wall of the Day push for the tags line.
    return stringArg("tags") ?
      {titleKey: "notif_push_drop_live_title", titleArgs: [], bodyKey: "notif_push_wotd_for_audience_body",
        bodyArgs: [stringArg("tags")]} :
      {titleKey: "notif_push_drop_live_title", titleArgs: [], bodyKey: "notif_push_drop_live_body",
        bodyArgs: [String(Number(message.args.wallCount ?? 0))]};
  case "followDigest": {
    const creators = Number(message.args.creatorCount ?? 0);
    const walls = String(Number(message.args.wallCount ?? 0));
    const shape = followDigestShape(creators, Number(walls));
    titleSuffix = `_${shape}`;
    titleArgs = {
      one: [stringArg("artistName")],
      solo: [stringArg("artistName"), walls],
      pair: [stringArg("artistName"), stringArg("secondArtistName"), walls],
      group: [stringArg("artistName"), String(creators - 1), walls],
    }[shape];
    tagsBody();
    break;
  }
  case "folderDigest": {
    const folders = Number(message.args.folderCount ?? 0);
    titleSuffix = folders > 1 ? "_more" : "_one";
    titleArgs = folders > 1 ? [stringArg("folderName"), String(folders - 1)] : [stringArg("folderName")];
    tagsBody();
    break;
  }
  case "reportNeedsReview":
    break;
  case "newContentReport":
    break;
  case "wallSubmittedForReview":
    bodyArgs = [stringArg("artistName"), stringArg("artistEmail")];
    break;
  case "streakReminder":
  case "wotdForCreator":
  case "winBack7":
  case "winBack14":
  case "winBack30":
  case "winBack60":
  case "drawWinner":
    break;
  default: {
    const exhaustive: never = kind;
    return exhaustive;
  }
  }

  return {
    titleKey: `${prefix}_title${titleSuffix}`,
    titleArgs,
    bodyKey: `${prefix}_body${bodySuffix}`,
    bodyArgs,
  };
}
