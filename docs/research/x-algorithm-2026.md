# X For You algorithm, 2026

This document describes how the X For You feed ranks posts, and what Prism took from it. The source is https://github.com/xai-org/x-algorithm at HEAD a284320b66a9dce35e6f5d6b052ee308eeb12326, dated 2026-11-17. Every fact cites `path@commit`, and the repo has no tags or release notes, so "releases" means the dated README updates and the commits.

## Pipeline stages

1. **Query hydration.** Loads the viewer data. This includes follows, blocks, mutes, seen posts and engagement history. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:286-352`
2. **Candidate sources.** The framework runs these in parallel. Thunder gives posts from followed accounts. The other sources give posts from other accounts. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:385-395`. See [Candidate sourcing](#candidate-sourcing).
3. **Candidate hydrators.** Add post and author data, such as media, language, engagement counts and reply ancestors. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:397-427`
4. **Pre-scoring filters.** Remove posts before scoring. The pipeline has 21 of them. The README omits three: `ZeroFavCodivertFilter`, `NewUserSoftNsfwFilter` and `FairShareRankingFilter`. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:432-455`
5. **Scorers.** They run in this order: `PhoenixScorer`, `ImmersiveVideoScorer`, `VMRanker`, `PageDecodeRerankScorer` and `PageRlExplorationScorer`. The last two are off by default. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:481-487`, `home-mixer/params/param.rs@a284320`
6. **Selector.** `TopKScoreSelector` sorts by score and keeps the top 50 posts. The result has 35 posts. Video carousel extras are added after the top 50. `home-mixer/selectors/top_k_score_selector.rs@a284320:14-27`, `home-mixer/params/config.rs@a284320:19-20`
7. **Post-selection hydrators.** Add visibility, media, video and ancestor data. The visibility hydrator checks each post. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:491-514`, `home-mixer/candidate_hydrators/vf_candidate_hydrator.rs@a284320`
8. **Post-selection filters.** Five filters run here: `VFFilter`, `AncillaryVFFilter`, `AncestorVideoFilter`, `DedupConversationFilter` and `VideoCarouselFilter`. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:515-520`
9. **Blending.** The blender adds ads, Who-to-Follow at position 6, prompts at position 0 and a feed survey at position 12. `home-mixer/candidate_pipeline/for_you_candidate_pipeline.rs@a284320`, `home-mixer/selectors/blender_selector.rs@a284320`, `home-mixer/params/config.rs@a284320:21-34`
10. **Side effects.** They run after the response. They store served results in caches and write stats. `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:523-545`

## Predicted actions and weights

The ranking model predicts one probability for each action. Each weight below multiplies the probability of its action. `phoenix/xrex/models/recsys_model.py@a284320:909-922`

Home-mixer values come from `home-mixer/params/param.rs@a284320`. vm-ranker values come from `vm-ranker/params.rs@a284320`.

| Action | home-mixer weight | vm-ranker weight | Citation (home-mixer line) |
|---|---|---|---|
| Favorite | 0.708 | 0.5 | `home-mixer/params/param.rs@a284320:448-450` |
| Reply | 5.0 | 5.0 | `home-mixer/params/param.rs@a284320:453` |
| Retweet | 1.0 | 1.0 | `home-mixer/params/param.rs@a284320:466` |
| Quote | 5.0 | 5.0 | `home-mixer/params/param.rs@a284320:502` |
| Share | 2.118 | 2.0 | `home-mixer/params/param.rs@a284320:488` |
| Share via DM | 5.0 | 5.0 | `home-mixer/params/param.rs@a284320:490-493` |
| Share via copy link | 0.0 | 20.0 | `home-mixer/params/param.rs@a284320:496-499` |
| Follow author | 4.0 | 4.0 | `home-mixer/params/param.rs@a284320:516-519` |
| Photo expand | 0.05 | 0.05 | `home-mixer/params/param.rs@a284320:468-471` |
| Video open | 0.0 | 0.07 | `home-mixer/params/param.rs@a284320:474-477` |
| Click | 0.274 | 0.3 | `home-mixer/params/param.rs@a284320:479` |
| Open link | 0.2 | 0.2 | `home-mixer/params/param.rs@a284320:480` |
| Profile click | 0.0 | 0.0 | `home-mixer/params/param.rs@a284320:482-485` |
| Video quality view | 0.0 | 0.0 | `home-mixer/params/param.rs@a284320:487` |
| Quoted click | 0.05 | 0.05 | `home-mixer/params/param.rs@a284320:504-507` |
| Quoted video quality view | 0.0 | 0.0 | `home-mixer/params/param.rs@a284320:510-513` |
| Dwell | 0.05 | 0.05 | `home-mixer/params/param.rs@a284320:501` |
| Continuous dwell time, per second | 0.0075 | 0.004 | `home-mixer/params/param.rs@a284320:540-543` |
| Continuous click dwell time, per second | 0.385 | 0.4 | `home-mixer/params/param.rs@a284320:546-549` |
| Post unexplored | 0.015 | 0.02 | `home-mixer/params/param.rs@a284320:522-525` |
| Not interested | -53.07 | -47.52 | `home-mixer/params/param.rs@a284320:553-556` |
| Block author | -31.2 | -31.2 | `home-mixer/params/param.rs@a284320:559-562` |
| Mute author | -58.8 | -58.8 | `home-mixer/params/param.rs@a284320:565-568` |
| Report | -234.0 | -234.0 | `home-mixer/params/param.rs@a284320:570` |
| Not dwelled | -0.02 | -0.02 | `home-mixer/params/param.rs@a284320:572-575` |

The weighted score is the sum of all weighted terms. Continuous terms, such as dwell seconds, use their predicted value times the weight. `xai-value-model/scoring.rs@a284320:112-120` A reply from a bidirectional follow adds 15.0 to its reply weight. `home-mixer/params/param.rs@a284320:455-458` A net negative score maps into the range 0 to 0.001, and a net positive score gets an offset of 0.001. `xai-value-model/weights.rs@a284320:4`, `xai-value-model/scoring.rs@a284320:282-291` The author diversity and out-of-network multipliers apply after the offset. `xai-value-model/scoring.rs@a284320:403-430` The production values are not public. The two default sets disagree on nine weights, so neither set is the served value. `home-mixer/params/param.rs@a284320:1`

## Candidate sourcing

- **In-network.** Thunder gives posts from the accounts the viewer follows. It keeps posts for 48 hours. `thunder/args.rs@a284320:48-49` It asks for up to 1200 posts (`ThunderMaxResults`, `home-mixer/params/param.rs@a284320`). It excludes seen posts. `home-mixer/sources/thunder_source.rs@a284320`
- **Out-of-network.** Five sources give posts from accounts the viewer does not follow.
  - Phoenix two-tower retrieval, up to 1000 posts. `home-mixer/params/param.rs@a284320:5` It scores by a dot product between user and candidate vectors. `phoenix/README.md@a284320`, "Retrieval: Two-Tower Model"
  - SimClusters, posts up to 48 hours old. `home-mixer/params/param.rs@a284320:839`
  - Popular posts, up to 500. `home-mixer/params/param.rs@a284320:1248`
  - TweetMixer, up to 800. `home-mixer/params/param.rs@a284320:36`
  - SID, up to 800. `home-mixer/params/param.rs@a284320:851`
- **Out-of-network factor.** Posts from accounts the viewer does not follow get a factor of 0.75. `vm-ranker/params.rs@a284320:242`, `xai-value-model/scoring.rs@a284320:327-336`
- **No fixed ratio.** No constant or code path sets a ratio of in-network to out-of-network posts. A search of `home-mixer/params`, `candidate_pipeline`, `sources` and `util` found none. The mix comes from the result count of each source and from the 0.75 factor.

## Filters and diversity

| Filter | Rule | Citation |
|---|---|---|
| Dedupe (`DropDuplicatesFilter`) | Keep the first copy of each post ID. | `home-mixer/filters/drop_duplicates_filter.rs@a284320:9-25` |
| Previously seen (`PreviouslySeenPostsFilter`) | Remove a post that the seen list or the impression Bloom filter reports. | `home-mixer/filters/previously_seen_posts_filter.rs@a284320:14-34` |
| Previously served (`PreviouslyServedPostsFilter`) | Remove a post that the served list holds. It runs for bottom page requests. | `home-mixer/filters/previously_served_posts_filter.rs@a284320:1-40` |
| Age (48 hours) | Keep a post for at most 172800 seconds. | `home-mixer/params/config.rs@a284320:41`, `home-mixer/filters/age_filter.rs@a284320` |
| Self post (`SelfTweetFilter`) | Remove posts by the viewer. | `home-mixer/filters/self_tweet_filter.rs@a284320:14` |
| Block and mute (`AuthorSocialgraphFilter`) | Remove posts by blocked and muted authors. | `home-mixer/filters/author_socialgraph_filter.rs@a284320:8-25` |
| Muted keywords (`ViewerMutedKeywordFilter`) | Remove posts that match a muted keyword. | `home-mixer/filters/viewer_muted_keyword_filter.rs@a284320` |
| Visibility (`VFFilter`, `AncillaryVFFilter`) | Drop a post when visibility filtering returns DROP. `AncillaryVFFilter` drops a post when its parent, quoted or reposted post was dropped. | `home-mixer/filters/vf_filter.rs@a284320`, `home-mixer/filters/ancillary_vf_filter.rs@a284320` |
| Dedupe conversation (`DedupConversationFilter`) | Keep one branch per conversation. | `home-mixer/filters/dedup_conversation_filter.rs@a284320`, `home-mixer/candidate_pipeline/phoenix_candidate_pipeline.rs@a284320:515-520` |
| Author diversity | Multiply the score by `(1 - floor) * decay^k + floor`. `k` is the number of posts from the same author ranked above. X uses decay 0.5 and floor 0.25. Prism uses floor 0.3. | `xai-value-model/scoring.rs@a284320:304-306`, `vm-ranker/params.rs@a284320:206-215` |
| DPP rerank | A determinantal point process. It gives up some score for less similarity between neighbours. Theta is 0.65. The pool is the top 150 posts. It needs a post embedding. A missing embedding gets a random unit vector. | `vm-ranker/scoring/mod.rs@a284320:43`, `vm-ranker/params.rs@a284320:266-277`, `vm-ranker/dpp.rs@a284320:105-106`, `vm-ranker/scoring/dpp_model.rs@a284320` |
| Candidate isolation | Candidates do not attend to each other. A post score does not depend on the other posts in the batch. | `README.md@a284320`, "Key Design Decisions", item 2. `phoenix/README.md@a284320`, "Ranking: Transformer with Candidate Isolation" |

## What changed per release

There are no tags. The dates below come from commit dates and the README "Notable Updates" section.

| Date | Commit | Change |
|---|---|---|
| 2026-01-20 | `aaa167b` | First public drop. Two sources, Phoenix and Thunder. The weight values are not in this drop. `home-mixer/lib.rs@aaa167b:5` |
| 2026-05-15 | `e414c17` | Candidate pipeline rewritten. Adds content understanding, ads and more sources. `candidate-pipeline/candidate_pipeline.rs@e414c17` |
| 2026-08-13 | `47c1bcd` | Large drop. Adds visibility filtering, labelling systems, SimClusters, training code and the weight values. Adds the weighted sum, author diversity and out-of-network rules. `README.md@47c1bcd`, `home-mixer/scorers/ranking_scorer.rs@47c1bcd` |
| 2026-08-14 | `c65aa17` | README clarifies how weights work. Adds `Brazil2026ElectionFilter`. `home-mixer/filters/brazil_2026_election_filter.rs@c65aa17` |
| 2026-08-25 | `0d3cdd8` | Dwell weight 0.0 to 0.05. Video open 0.05 to 0.07. Video quality view 0.05 to 0.0. `home-mixer/params/param.rs@0d3cdd8` |
| 2026-09-24 | `44d37eb` | Deletes `ranking_scorer.rs`, 1255 lines. Adds `xai-value-model/` and `home-mixer/scorers/value_model.rs`. Diversity and out-of-network rules move to `xai-value-model` and `vm-ranker`. `git show --stat 44d37eb` |
| 2026-09-29 | `a707cc2` | Click weight 0.4 to 0.3. Continuous click dwell 0.0 to 0.4. Not interested -43.2 to -47.52. `home-mixer/params/param.rs@a707cc2`, `vm-ranker/params.rs@a707cc2` |
| 2026-10-08 | `35650fb` | Adds a continuous loss for predicted time spent. `phoenix/xrex/models/loss_recsys.py@35650fb` |
| 2026-10-13 | `e1a0375` | Adds a long-dwell retrieval head. Favorite 0.5 to 0.6. Continuous dwell 0.004 to 0.006. Video open 0.07 to 0.02. `phoenix/xrex/configs/xrecsys_two_tower.py@a284320:294-297` |
| 2026-10-14 | `17c96bf` | Favorite 0.6 to 0.66. Not interested -47.52 to -52.272. `home-mixer/params/param.rs@17c96bf` |
| 2026-10-28 | `5ed7963` | Removes `Brazil2026ElectionFilter`. `git show --stat 5ed7963` |
| 2026-11-05 | `021afa4` | Favorite 0.66 to 0.708. Click 0.3 to 0.274. Share 2.0 to 2.118. Video open 0.02 to 0.0. Continuous dwell 0.006 to 0.0075. Continuous click dwell 0.4 to 0.385. Not interested -52.272 to -53.07. `home-mixer/params/param.rs@021afa4` |
| 2026-11-13 | `590f392` | Share via copy link 20.0 to 0.0 in home-mixer only. Adds DPP history to the vm-ranker request. `home-mixer/params/param.rs@590f392`, `home-mixer/scorers/vm_ranker_request.rs@590f392` |
| 2026-11-14 | `30647a8` | Turns on sending DPP history to vm-ranker. History cap 200 to 50. `home-mixer/params/param.rs@30647a8` |
| 2026-11-17 | `a284320` | HEAD. Adds not-dwelled power parameters (both 0.0), value model mode `weighted`, and a 48-hour age check through `time_from_id_opt`. `home-mixer/params/param.rs@a284320`, `home-mixer/filters/age_filter.rs@a284320` |

## What Prism had before (PR #411)

This section cites `lib/core/personalization/taste_profile.dart@6b733ee4e` and `lib/features/personalized_feed/data/personalized_ranking_service.dart@6b733ee4e`.

- **Taste score.** Open 1. Favourite 3. Download 4. Set 6. Less like this -8. Passed over -0.5. A weight halves every 30 days.
- **Source priors.** Following 1.0, taste 0.9, fresh 0.85, gems 0.85, Wallhaven 0.75, Pexels 0.7. The external priors act as the out-of-network discount.
- **Author diversity.** `(1 - 0.3) * 0.5^k + 0.3`, where `k` is the number of walls from the same creator already picked.
- **Impression fatigue.** The score multiplies by 0.4 for each show. Shows count over 14 days. `lib/features/personalized_feed/data/feed_impression_store.dart@6b733ee4e`
- **Noise.** The score multiplies by a random value from 0.7 to 1.3.
- **Hidden walls.** Hidden walls do not return, except after Undo.
- **External walls.** External walls take at most half a page.
- **Explore slots.** One slot in 8, 5 or 3, by feed mix (Familiar, Balanced, Adventurous). `lib/features/personalized_feed/domain/entities/feed_mix.dart@6b733ee4e`

## X ideas for a wallpaper feed

The harness runs seven personas. Results are percentages unless the row says otherwise. Results come from the harness decision log and the kept rule set table.

| X idea | What it means for a wallpaper feed | Fits on device? | Expected effect | Result in the harness |
|---|---|---|---|---|
| Weighted sum of predicted actions, with hard negatives | Each action has a weight. A negative term keeps its force when the user has many positive signals. | Yes. It is a weight table and a cap on the negative scale. | A "Show less like this" stays strong for users with many likes. | Kept as `hardNegatives`. On the less like cars persona, disliked share fell from 2.2% to 0.0%. Hit moved from 73.6% to 72.8%, within noise. |
| Share and follow-like actions (share, folder add) | Share and folder add count as strong votes. X weights share about three times as high as a favourite. | Yes. The events are on the device. Two weights are added. | Walls like the ones a user shares or saves rank higher. | Kept as `newActions`. Grid saver hit moved from 21.1% to 45.1% with all kept rules. Alone, it moved from 23.3% to 37.3%. |
| Not dwelled as a weak negative (scrolled past) | A wall the feed showed, and the user never tapped, counts as a weak no. X uses -0.02 for not dwelled. | Yes. Impressions already live on the device. | Walls passed over lose weight. | Kept as the "came back untapped" version: -0.3, once per wall, at most 60 signals. Anime and nature hit moved from 64.3% to 67.9%. New user moved from 37.5% to 40.0%. Grid saver moved from 23.3% to 32.9%. The second-show version was reverted. Fatigue stops second shows, so it almost never fires. |
| Candidate isolation | A wall score uses only that wall, the taste profile and its own impressions. Diversity runs after scoring. X does the same. | Yes. This is already true. | Scores do not change when the batch changes. | Already in master. No change. |
| Author diversity decay | Each extra wall from one creator counts less. X uses decay 0.5 and floor 0.25. | Yes. Already present, with floor 0.3. | One creator cannot fill a page. | Floor 0.25 was reverted. Max per creator fell 0.06 to 0.5. Hit fell 0.3 to 2.5 points. Cold start fell 0.6 to 1.0 points. It hurts cold start. |
| Out-of-network discount | Posts from outside the follow graph get a lower prior. X uses a factor of 0.75. | Yes. Already present as source priors, from 1.0 down to 0.7. | Walls from followed creators rank higher. | Already in master. No change. |
| Previously seen and served filters | Seen walls do not come back. X removes seen and served posts. | Yes. Already present as impression fatigue (0.4 per show) and the session seen list. | Repeats drop out. | Already in master. No change. |
| Dedupe | X drops repeated posts and keeps one branch per conversation. Prism keeps one wall per light and dark pair. Duo walls are one image each, so there are no Duo pairs to dedupe. | Yes. The variant group is on the device. | No light and dark pair shows twice. | Kept as `dedupeVariants`. Variant duplicates fell from 1 to 9 per persona to 0. Hit within noise. |
| DPP diversity rerank | Each wall is picked for its score and for how different it is from walls already picked. | No. X needs a post embedding for each post. The on-device ranker has none. | Less similar walls in a row. | Not kept. A category decay stand-in was reverted. Amoled hit fell from 46.3% to 33.9%. Cold start fell from 72.5% to 32.1%. Every persona lost 11 to 18 points of hit and 20 to 40 points of cold start. |
| Phoenix ranking transformer and two-tower retrieval | A large neural model predicts actions and finds candidates. | No. It needs a server model, GPU serving and a large engagement corpus. | Better personal ranking at scale. | Not tested. |
| Real-time engagement sequence of 1024 actions | The model reads the user's last 1024 actions in order. | No. Our cap is 300 signals on the device, and no model reads a sequence. | Ranks by recent order and context. | Not tested. |
| Author cold-start Thompson sampling | New creators get a random chance at a fixed slot, from a Beta prior. | No. It needs impression counts per author across all users, a server count. | New creators get shown and tested. | Not tested. |
| Visibility filtering labels | Server labels decide which posts to hide. | No. The labels come from server models and rules. The app already filters AI, anime and blocked creators on the device. | Safety labels for all creators. | Not tested. |
| Explore share | A fixed share of slots goes to walls outside the taste. | Yes. Already present as Familiar, Balanced and Adventurous slots. | Keeps variety on the page. | Already in master. A wider explore test, which accepts taste from -0.25 to 0, was reverted. Hit fell 1.5 to 4.6 points. |

## Dropped ideas

- **Scrolled past on the second show (3a).** Fatigue stops second shows, so the rule almost never fires. Gain was 0.0 to 0.4 points, within noise.
- **Category decay as a DPP stand-in (4).** Decay 0.7 and floor 0.4. Amoled hit fell from 46.3% to 33.9%. Cold start fell from 72.5% to 32.1%. A poor proxy for DPP.
- **Author floor 0.25 (6).** Hurts cold start. Hit fell 0.3 to 2.5 points. Cold start fell 0.6 to 1.0 points.
- **Wider explore (7).** Hit fell 1.5 to 4.6 points. Max category changed by -0.1 to -1.4. Trades hit for diversity.
- **Score noise 0.85 to 1.15 (8).** Hit changed from -0.8 to +2.5 points. Cold start fell 1.4 points for stale interest and 0.8 points for broad taste.
- **DPP rerank.** Needs a post embedding. The on-device ranker has none.
- **Phoenix transformer and two-tower retrieval.** Needs a server model, GPU serving and a large corpus.
- **Long engagement sequence.** Our cap is 300 signals. No model reads a sequence.
- **Thompson sampling for new authors.** Needs impression counts per author across all users.
- **Visibility labels.** The labels come from server models. The on-device filters already cover AI, anime and blocked creators.

## Harness results

The offline check is `test/features/personalized_feed/replay/`. Seven seeded users browse a fixed catalog of 1,030 Prism, 80 Wallhaven and 60 Pexels walls for 8 sessions of 2 pages, over 20 seeds. hit@24 is the share of page 1 in the true taste. Cold hit is that share on session 1. Repeat is the share of page 1 that the last session showed. Run `REPLAY_TABLE=1 fvm flutter test test/features/personalized_feed/replay/` to print this table.

| persona | ranker | hit@24 | cold hit | max/creator | max category | repeat | disliked | hidden back | variant dupes |
|---|---|---|---|---|---|---|---|---|---|
| amoled only | master | 46.0% | 72.5% | 2.66 | 40.0% | 2.2% | 0.0% | 0 | 5 |
| amoled only | x2026 | 51.1% | 72.5% | 2.83 | 42.8% | 3.6% | 0.0% | 0 | 0 |
| anime + nature | master | 64.8% | 70.6% | 2.42 | 32.9% | 0.9% | 0.0% | 0 | 2 |
| anime + nature | x2026 | 72.7% | 70.6% | 2.82 | 36.7% | 1.8% | 0.0% | 0 | 0 |
| new user | master | 37.2% | 7.9% | 2.58 | 33.9% | 1.4% | 0.0% | 0 | 1 |
| new user | x2026 | 45.3% | 7.9% | 2.97 | 40.2% | 2.9% | 0.0% | 0 | 0 |
| less like cars | master | 73.6% | 100.0% | 2.81 | 37.2% | 1.3% | 2.2% | 0 | 2 |
| less like cars | x2026 | 77.9% | 100.0% | 2.93 | 39.0% | 1.6% | 0.0% | 0 | 0 |
| stale interest | master | 41.4% | 38.5% | 2.86 | 38.6% | 1.8% | 0.0% | 0 | 4 |
| stale interest | x2026 | 46.1% | 38.5% | 3.12 | 42.2% | 2.8% | 0.0% | 0 | 0 |
| grid saver | master | 21.1% | 7.1% | 2.20 | 31.5% | 0.8% | 0.0% | 0 | 4 |
| grid saver | x2026 | 45.1% | 7.1% | 2.72 | 39.8% | 2.8% | 0.0% | 0 | 0 |
| broad taste | master | 79.7% | 88.7% | 3.92 | 39.2% | 0.5% | 0.0% | 0 | 9 |
| broad taste | x2026 | 82.6% | 88.7% | 4.31 | 41.7% | 1.0% | 0.0% | 0 | 0 |
