# X 規約×アルゴリズム分析レポート — RT/フォロー要求（エンゲージメント要求）の制限・凍結リスク — 2026-08-17

| 項目 | 値 |
|---|---|
| 生成日 | 2026-08-17 |
| 調査課題 | 投稿で RT（リポスト）やフォローを求める行為は、アカウントの制限・凍結リスクを高めるか |
| コード根拠の対象コミット | 上流 `c65aa179db7bdd61e2c2821eac87f208a105c053`（main, 2026-08-14。ローカル git オブジェクトで実地確認済み） |
| 調査方法 | Dynamic Workflow 4レーン（grox スパム分類精読 / 執行系全域 grep / 規約 Web 調査 / 実執行 Web 調査）→ refuter による主張別敵対的検証10件 → リード統合 → code-reviewer 検収。本文のコード引用は全件、`git show c65aa179:<path>` で実在と行番号を確認済み |
| 関連レポート | `reports/2026-07-20-baseline.md`（構造ベースライン）/ `reports/2026-08-14.md`（執行系モジュール初公開の解析）/ `reports/2026-08-15.md`（bdsm enforcement_note 等） |

> **取得上の注記**: help.x.com は調査環境から Cloudflare により全経路 HTTP 403 のため、規約の逐語は (1) 検索索引経由の本文一致、(2) 米連邦最高裁が保全した 2024 年版 X Rules PDF（supremecourt.gov）、(3) 複数の独立二次報道、の三系統でクロスチェックした。一字一句の最終確認はブラウザでの実取得を推奨（対象 4 ページは §7 に列挙）。

---

## 1. 結論（TL;DR）

**単発の「RT お願いします」だけで凍結される規約上の根拠は無い。しかし「繰り返す」「相互交換を持ちかける」のいずれかが加わった時点でリーチ制限（スパムラベル）の公式根拠が確定し、さらに収益化プログラム参加者に限っては「勧誘 3 回以上で凍結審査へ回付」が当時のプロダクト責任者により告知されている**（一次情報は本人の X ポストで独立検証なし・本人は 2026-08-06 退任: §3.3）。2026 年の X はこの領域の執行を明確に強化しており、コード側にもエンゲージメント要求専用の検出カテゴリが実在する。

### リスク段階表

| 行為 | 規約上の扱い | 実際の帰結 |
|---|---|---|
| 単発の「よければ RT してね」 | 明文の禁止列挙なし | 確定的な制裁根拠なし（ただし品質評価プロンプトは非公開領域） |
| フォロー&リポストで応募の懸賞（単発） | キャンペーンガイドラインが許容 | 複数アカウント作成の助長・重複投稿の強制は「全アカウント凍結もありうる」と明記 |
| **繰り返しの**「いいね/RT/フォローして」 | エンゲージメントベイトとして検出・ラベル対象（§2.1） | **投稿ラベル** `SPAM_HIGH_RECALL` → 当該投稿が**非フォロワーへの推薦から除外**（アカウントラベルへの自動昇格は公開分に無い: §2.3）。高 PageRank アカウントでも免除なし |
| 「フォロバします」等の**相互交換の提示** | Authenticity ポリシーが明文禁止（§3.1） | スパム判定 → リーチ制限。段階的執行（読み取り専用化 → 凍結）の入口 |
| 収益化プログラム参加中の勧誘 | Original Content Rewards 規約が逐語で禁止（§3.3） | **3回以上でプログラム除外＋ポリシーチームへ凍結審査回付**と当時の責任者が告知（2026-07-16。約4,000アカウント除外も本人発信・独立検証なし） |
| 大量フォロー→解除・無差別フォロー・bot/複数アカウント | Authenticity ポリシーで禁止（相互性・自動化がなくても単独成立） | **自動凍結のラベル指定ルールはここ**（inauthentic/cluster_spam/anchor 系）。ただし終端に既定 suspend フォールバックあり（§2.3） |

---

## 2. コード側の根拠（上流 c65aa179）

### 2.1 エンゲージメントベイト専用の検出カテゴリが実在し、大アカウントでも免除されない

- `grox/flows/ptos/state.py:33-40` に `SpamEngagementFarming` / `SpamEngagementTrading`（交換）/ `SpamEngagementBaiting`（要求・煽り）がポリシー型として列挙されている。
- `grox/flows/ptos/task_write_safety_post_annotations_result_sink.py:234-247`: Spam カテゴリのうち **Baiting / Farming の2型だけは `is_high_page_rank_user` の免除なしで無条件に `SpamHighRecall` ラベルが付く**（コード上の enum 名。付与先は `tweet_id`＝投稿ラベル `SPAM_HIGH_RECALL`。§2.2 のアカウントラベル `SpamHighRecall` とは別物）。他のスパム型は高 PageRank ユーザーなら免除される。X がこの行為を狙い撃ちしている構造的証拠。
- ただし「どの文言までがベイトか」の判定実体（LLM プロンプト .j2）は「ゲーム化防止のため」意図的に非公開（`grox/flows/ptos/prompts.py:11` のコメントおよび README「What's not in this repo?」）。境界は外部から原理的に検証不能。

### 2.2 ラベルの効果は公式定義済み — 帰結は「リーチ制限」であって即凍結ではない

- `under-the-hood/strato/lib/underTheHoodLabels.strato:34-41`: 投稿ラベル `SPAM_HIGH_RECALL` = "Post hidden from recommendations to non-followers"、`SPAM` = "Post is not shown on X."（Authenticity ポリシー違反判定時）。
- 同 `:124-127`: アカウントラベル `SpamHighRecall` = "The account's posts are hidden from recommendations to non-followers."
- 配信側の実装: `SpamHighRecallDropRule`（`visibility-filtering/rules/tweet_label_drops.rs:70-75`）は `timeline_home_recommendations_policy`（`registry.rs:138-153`）にのみ組み込まれ、フォロー中タイムライン用の `timeline_home_policy`（`registry.rs:134-136`）には含まれない。テスト `spam_high_recall_drops_oon_but_allows_in_network`（`registry.rs:419-`）が「in-network は Allow / OON は Drop」を直接アサートしており、「非フォロワー向け推薦からの除外（フォロワーへの配信は残る）」が正確な効果。

### 2.3 凍結（`act_suspend_user`）の公開ルールにベイトは登場しない

- `abuse-enforcement-service/service-lib/rules/enforcement_user.yaml`: ラベル指定の凍結ルールは `anchor_campaign_suspend`(:36) / `anchor_campaign_suspend_cse`(:43, policy Cse・恒久) / `inauthentic_detection_v45` / `cluster_spam_extended` / `cluster_spam` の5本＝ **bot 性・クラスタ性・量**が絡む場合（CSE 系の :43 を除く）。加えて末尾に `when: "true"` の**終端フォールバック `act_suspend`（既定 suspend, perm: false, policy: PlatformManipulation）**があり、ルールエンジンは記載順の先勝ち評価（`src/rules.rs:256-277` `decide_with`）のため、skip 条件にも既知ラベルにも一致しなかった user スコアイベントは**既定で凍結側へ落ちる**（同種の `enforcement_post.yaml` は終端が既定 skip で、user 側とは明確に非対称）。
- ただし `SpamEngagementBaiting` はこのサービスへの入力ラベルとして一切登場しない（abuse-enforcement-service / visibility-filtering / safety-label-user-agg / botmaker-rules への `git grep` 0件）。**ベイト経路から上記の終端フォールバックに到達する公開証拠は無い**——このサービスに流れるのは `inauthentic_detection_v45` / `cluster_spam(_extended)` / `anchor_campaign_*` / `llm_slop_user` / `SpamEmbeddingMajorityPoster` / `enforcement_cusp_*` 等のアカウント側スコアイベントで、いずれも grox の投稿ポリシー型とは別系統。ベイトの帰結は §2.1-2.2 の投稿ラベル経路に閉じている（公開分の範囲では）。
- 投稿ラベル→ユーザーラベル昇格の許可リストは NSFW 系 2 種のみをハードコード（`safety-label-user-agg/postToUserLabelRules.strato:96-99` `allowedApplyUserLabels = Set("POSSIBLY_NSFW_ACCOUNT", "NSFW_HIGH_PRECISION")`）。ベイト投稿のラベルがアカウントラベルへ自動昇格する経路も公開分には無い。
- 免除機構: フォロワー数閾値（公開値 12.34 はモックと明記、本番値非公開）または PageRank 評判（`cred.is_high || cred.score >= 50.0`）で自動執行をスキップ（`enforcement_user.yaml:18-31`）。自動制裁リスクは低評判・低フォロワー側に偏る設計。ただし §2.1 のとおりベイトの投稿ラベル付与だけは免除なし。
- 注意: 同 yaml は「GrowthBook 動的設定のミラー」であり、公開されたルール集合が本番の全てとは限らない（要確認）。

### 2.4 「フォローする行為」自体が監視対象になる実例

- `botmaker-rules/scarecrow/bot/FollowFromActorWithPinnedLowQualityOrBadUrl.bot`（id 20732, event: follow, isActive: true）: 固定ポストに低品質/悪性 URL を持つユーザーの**フォロー行為そのもの**をトリガーに、アカウントへ `SPAM_HIGH_RECALL` を 1 週間付与（高 PageRank・グレーバッジは除外）。
- `bdsm/README.md:30-31`: 行動系列 Transformer が FollowBot / LikeBot / **EngagementAmplifier** / RTBot 等 8 ヘッドで判定。EngagementAmplifier 配下には 7 サブラベル（`bdsm/runtime/heads.py:40-53`: LIKE_RETWEET_PAIR / FOLLOW_THEN_FAV_PIPELINE / FOLLOW_THEN_REPLY_PIPELINE / REPLY_THEN_FOLLOW_PIPELINE / ENGAGEMENT_AMPLIFIER / FOLLOW_LIKE_AMPLIFIER / OUTREACH_PIPELINE_BOT）があり、相互エンゲージメント水増しの**行動側シグネチャ**が専用の検出対象になっている（判定閾値は `bdsm/runtime/sink_policy.yaml` の 9.99 センチネルで伏字。`reports/2026-08-15.md` §3.5 の enforcement_note ゲートも参照）。

### 2.5 副次的知見: 相互フォロー「状態」はむしろ加点

`home-mixer/params/param.rs:310-321` に `BidirectionalFollowReplyWeightBoost`（既定 15.0）/ `BidirectionalFollowDwellWeightBoost`（既定 **0.0**＝現状無効）が存在し、実効の加点は返信側のみ。罰されるのは「交換の取り決め・勧誘」であって、相互フォロー関係が多いこと自体ではない。

### 2.6 ベースライン（2026-07-20）の前提の更新

1. **「重み実数値はリポジトリに無い」→ 更新**（`reports/2026-08-15.md` §3.2 で既報。本節は再掲）: `home-mixer/params/param.rs` に既定値が公開された（Favorite 0.5 / Retweet 1.0 / Share 2.0 / Reply 5.0 / NotInterested -43.2 / Block -31.2 / Mute -58.8 / **Report -234.0**。ヘッダ `:1` に「config の feature-switch 既定値のミラー（最終同期 2026-08-12）」と明記——feature switch である以上、本番値は別であり得る〔推論〕）。なお README は「1 通報=468 いいね相当」式のカウント換算を明確に誤りと否定している（重みは予測**確率**に掛かる）。
2. **「リポジトリに engagement bait の語は無い」→ 誤り**: これは本調査の初期 grep（旧スナップショットの作業ツリーに対する実測）による誤認で、過去レポートの記載ではない。上流 c65aa179 には §2.1 のとおり `SpamEngagementBaiting` が実在する。

---

## 3. 規約側の根拠（Web、アクセス日 2026-08-17）

### 3.1 Authenticity ポリシー（旧「プラットフォーム操作およびスパム」を包含する上位カテゴリ）

- 明文禁止（完全一致検索で本文確認）: "**Coordinating to exchange engagement** in any X features, such as Likes, Polls, Replies, **Reposts**, Lists, Views, or **Follows**"、"Engaging in 'follow churn'"、"indiscriminate following"、"account metric inflation"、"Engaging with posts aggressively **or** through the use of automation"。
- 重要な読み: follow churn・無差別フォロー・アグレッシブなエンゲージは**相互性・自動化がなくても単独で違反成立**する（"or" の選言）。「単独・手動なら安全」は誤読。
- 一方、「自分のフォロワーに単に拡散を頼む行為」は禁止列挙に見当たらない（不在証明の限界あり。help.x.com 全文の直接取得は不可）。
- URL: https://help.x.com/en/rules-and-policies/authenticity （2024 年版の逐語は https://www.supremecourt.gov/opinions/URLs_Cited/OT2023/22-277/22-277-12.pdf で裏取り）

### 3.2 キャンペーンガイドライン — 「フォロー&リポストで応募」は許容

- 懸賞での単発のフォロー/投稿要請自体は許容（"may offer prizes for posting a particular update, for following a particular account"）。
- 禁止・非推奨: 複数アカウント作成の助長（"liable to get **all of their accounts suspended**"）、「最多リポスト者が優勝」等の重複投稿の助長（"Posting duplicate ... is a violation of the X Rules"）。
- URL: https://help.x.com/en/rules-and-policies/x-contest-rules

### 3.3 収益化レイヤー — 唯一の「要求行為そのもの」への明文禁止

- Original Content Rewards Program（2026-08-08 発表、09-08 移行）: "**Do not solicit engagements**: **repeatedly** instructing users to engage with posts, such as asking to like, reply, bookmark, **follow, or repost**." 罰則は「重大性に応じプログラムから一時的または恒久的に除外（異議申立可）」。
- 当時のプロダクト責任者 Nikita Bier（2026-07-16、本人の X ポスト）: 「勧誘（例:『返信した人は全員フォローします』）を **3 回以上**でプログラム除外＋**ポリシーチームへ凍結審査として回付**。Grok がこれらを全部検出する。約 4,000 アカウントを除外した」— 件数・運用とも本人発信で独立検証は無い（二次報道は Social Media Today / TechCrunch 等）。
- Creator Monetization Standards: engagement bait を収益化不可カテゴリとし、措置として「非フォロワーへのアルゴリズム推薦の制限」を明文化。
- URL: https://help.x.com/en/using-x/original-content-rewards / https://help.x.com/en/rules-and-policies/content-monetization-standards / https://www.socialmediatoday.com/news/x-updates-its-engagement-bait-detection/825495/ / https://x.com/nikitabier/status/2077774853650944028
- 留保: Bier は 2026-08-06 に X を退任しており、「3 回ルール」運用の継続性は要確認。

### 3.4 執行の段階構造と経営層の発信

- 公式の段階的執行: 投稿単位のリーチ制限 → アカウントの一時読み取り専用化 → 恒久凍結（https://help.x.com/en/rules-and-policies/enforcement-options ）。いきなり凍結ではなく、まずリーチ制限。
- Musk 2024-04-19: "Any accounts doing engagement farming will be suspended and traced to source"（Snowflake ID から日時再計算・3 独立ソースで本文一致を確認）。同日「compelling content での engagement farm は問題ない、spam がダメ」と限定も付している。
- 「エンゲージメント要求**そのものだけ**を理由に凍結された」個別事例の一次報道は発見できなかった。確認できた凍結事例は自動化・大量操作・複数アカウント由来（2026-03 の誤検知凍結波もスパムフィルタのバグ由来で 99% 復旧と説明されている）。

---

## 4. 日本語圏の通説の検証

| 通説 | 判定 |
|---|---|
| 「拡散希望・RT 希望と書くと凍結される」 | ❌ 公式の直接根拠なし（代表的な日本語記事は公式 URL を提示していない）。正しくは「反復・相互交換・収益化の条件が揃うとリーチ制限〜凍結審査が実在」 |
| 「相互フォローで制限される」 | △ 部分的。禁止は「交換の**取り決め・勧誘**」（follow trains / Repost for Repost）。相互フォロー状態自体はランキングで加点（§2.5） |
| 「フォロバ企画・RT 企画は危険」 | ✅ 相互交換の提示は Authenticity ポリシーの明文禁止に直撃。収益化参加中なら「3 回で凍結審査回付」が当時の責任者により告知されている（§3.3・独立検証なし） |

---

## 5. Xユーザー/クリエイターへの実務ガイド

**Do**:
- 懸賞は「フォロー&リポストで応募」の単発設計に留める（重複投稿・複数アカウントを促さない）
- 拡散を頼むなら単発・非反復で、交換条件（フォロバ・RT 返し）を付けない
- 収益化参加者は「いいね/RT/フォローして」系の CTA を原則やめる（3 回ルールの告知あり: §3.3）

**Don't**:
- 「フォロバ100%」「RT した人全員フォロー」等の相互交換の提示（明文禁止。なお高 PageRank 免除が効かないのは Baiting/Farming 判定の場合で、Trading〔交換〕判定は免除側: §2.1）
- 同種の要求文言の反復（repeatedly が規約上の発動要件）
- 大量フォロー→解除（follow churn）、無差別フォロー、bot・複数アカウント運用（自動凍結のラベル指定ルールはここ。終端の既定 suspend フォールバックも含め §2.3）
- 固定ポストに低品質/怪しい URL を置いたままのフォロー営業（フォローイベント起点でアカウントラベルが付く実ルールあり: §2.4）

---

## 6. 不確実な点（要確認）

- ベイト判定の境界（LLM プロンプト .j2）は意図的非公開。「単発の RT 希望」が実際にどう採点されるかは外部から検証不能。
- enforcement の本番しきい値（フォロワー数フロア等）はモック値と明記されており非公開。リーチ低下の定量（何%減か）も公式・第三者いずれからも取得できず。**言えるのは符号と経路まで、大きさは不明**。
- 公開ルール（GrowthBook ミラー・botmaker 一部除外）が本番の全集合とは限らない。「公開コードに無い＝本番に無い」は本件でも成立しない。
- help.x.com 4 ページ（authenticity / x-contest-rules / original-content-rewards / content-monetization-standards）の逐語はブラウザ実取得での再確認を推奨。
- Bier 退任（2026-08-06）後の「3 回ルール」運用継続性。

---

## 7. 検証メタデータ

- Find フェーズ 4 レーン（コード2 / Web2）→ refuter 検証 10 主張: CONFIRMED 2 / PARTIAL 7 / REFUTED 1 → リード反映後、code-reviewer 検収（CRITICAL 1 / WARNING 7 を検出、全件修正済み）。
- REFUTED・PARTIAL の主因は「作業ツリーが旧世代（0bfc2795 相当）のまま grep していた」ことによる過小評価で、上流 c65aa179 での再検証結果を本レポートに反映した。**本文のコード引用は全件、`git show c65aa179:<path>` で実在と行番号を確認済み**。
- 運用上の注意: 本リポジトリの作業ツリーは監視レポート生成用に旧スナップショットを保持しているため、コード根拠の grep は必ず `git show <上流コミット>:<path>` 側で行うこと（作業ツリー grep は 2 世代古い結果を返す）。
- 本レポートは差分監視レポートではないため `monitoring/state.json` には登録しない（トピック別分析レポート）。
