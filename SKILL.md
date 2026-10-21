# Madfu Manager: NewAPI and Hong Kong Host Daily Operations

- Run daily operations for the user's NewAPI relay station and for basic upkeep of its Hong Kong host.

- Treat NewAPI as the QuantumNous new-api fork at v1.0.0-rc.45 or later, not the CalciumIon original.

- Work in `/home/newapi` on host 39.109.62.190, where the systemd unit `newapi` runs `/home/newapi/new-api --port 3000 --log-dir /home/newapi/logs` against the SQLite database `/home/newapi/one-api.db`.

- Serve users through `https://ai.aobzii.cn`, which nginx terminates and proxies to port 3000.

- Keep AstrBot business, other sites' business and the Madfu stack on the Aliyun host out of scope, and touch them only when their resource use affects this host.

## Server addresses

- Manage the Hong Kong host at public address 39.109.62.190, Tailscale address 100.70.12.35 with tailnet name hk-server, because NewAPI and its database live there.

- Reach that host as root through `~/workspace/services/hk_ssh.sh`, and reach its public service through `https://ai.aobzii.cn`.

- Record the Hong Kong host shape as Ubuntu 24.04 with 4 vCPU, about 3.9 GB of memory and a 50 GB disk, and verify it live before quoting it.

- Keep the Aliyun host address here for reference only, at public address 47.116.53.224 and Tailscale address 100.68.14.111 with tailnet name aliyun-madfu, reached as root through `~/workspace/services/aliyun_ssh.sh`.

- Never operate the Aliyun host under this skill, because it runs the Madfu stack and the panel at mc.aobzii.cn under their own rules, and its address is listed only so the two hosts never get confused.

## Apply the three permission tiers

- Do tier 1 work directly without asking, because it is read only.

  - Read live configuration, logs, balances and channel state.
  - Run the health check script and calculate charges, overcharges and refund amounts.
  - Write investigation reports for the user to decide on.

- Announce tier 2 work in one line, then do it, because it is low risk and reversible.

  - Restart `newapi` or reload nginx.
  - Take a database snapshot and pull a backup copy to this sandbox.
  - Prune pulled backup copies that are older than 3 days.

- Stop and get the user's explicit approval for every tier 3 change, every time.

  - Change any price, `GroupRatio` value or `billing_setting.billing_expr` expression.
  - Refund a user, adjust a user's quota or change a token's quota.
  - Add, remove or edit a channel, including its key, base URL, model list and `model_mapping`.
  - Create or delete a user or a token, upgrade the binary, or change DNS or certificates.
  - Delete production data of any kind.

- Never invent a price, because the user supplies the upstream cost, his selling price and the group assignment whenever a channel is added or repriced.

- Keep the user's own chore his, because he maintains each token's group to model visibility himself unless he asks for help with a specific token.

- Report measured numbers with their method and window, label every inference as an inference, and say unknown when nothing was run.

## Connect and read live state

- Reach the host with `~/workspace/services/hk_ssh.sh "<cmd>"`, which logs in as root at 39.109.62.190 through the egress proxy in BatchMode and takes about 5 to 30 seconds per call.

- Batch related checks into one SSH call, because each new call pays the proxy setup cost again.

- Read live data from the database on the host, because copies on this sandbox go stale and a running WAL database loses data when its files are copied directly.

- Read the database read only from the host with python3, because the host has no sqlite3 CLI.

  - Connect with `sqlite3.connect("file:/home/newapi/one-api.db?mode=ro", uri=True)` in python3.
  - Check the schema with `PRAGMA table_info(<table>)` before writing a query against a table.

- Convert times carefully, because the host clock is UTC and the user lives at UTC+8, while `logs.created_at` is unix seconds and needs no timezone conversion.

- Keep keys, passwords and tokens out of chat, reports, memory and this skill, and read channel keys only on the host when a test needs one.

## Run the health check and report only exceptions

- Run `~/workspace/custom-skills/madfu-manager/scripts/health-check.sh` for any health question, because it checks services, disk, memory, swap, both HTTP paths, certificate days left, database `quick_check`, channel status and the last 24 hours of consumption in one read only pass.

- Treat the check as on demand, because the user wants no timed patrol and no scheduled channel tests.

- Stay silent or answer one line when the result is OK and the user did not ask for detail, because he wants reports only when something is abnormal.

- Report an anomaly with its measured value, its threshold, its likely blast radius and the tier of the fix, and stop before any tier 3 fix.

- Use these thresholds from the script, disk at 75 percent warns and 85 percent alarms, memory available under 500 MB warns and under 250 MB alarms, and a certificate at 30 days warns and at 14 days alarms.

- Read a rising zero completion count as a lead, not a verdict, and break it down by model and channel before calling it overcharging.

## Investigate a user or billing complaint

- Pull the user's logs by default when he names a user or describes a symptom, because he approved default log access and calculation for complaints on 2026-10-20.

- Find the user in `users` first and record the id, username, current `quota` and `used_quota`, because names repeat less reliably than ids.

- Query `logs` for that `user_id` over the window the complaint covers and group by `model_name`, `channel_id` and `type`, summing `quota`, `prompt_tokens` and `completion_tokens`.

- Reconcile the log quota sum against the change in `users.used_quota`, because token `remain_quota` and `unlimited_quota` never prove what was charged.

- Remember that `unlimited_quota = 1` does not make calls free, because it only skips the token's own remain check while the user's `used_quota` still grows.

- Convert quota to dollars with 1 USD = 500000 quota and show the arithmetic in the report.

- Inspect the `other` field on suspect rows, because `admin_info` there records the billing path, the routing attempts and whether local token counting was used.

- Split the verdict into confirmed facts, inferences and unknowns, and name the upstream test that would settle an unknown.

- Write the result as a report with the user, the window, the call count, the amount charged, the amount that should have been charged, the overcharge amount, the root cause and one refund recommendation.

- Stop after the report, because refunding is tier 3 and the user decides the amount and the method.

## Investigate the root cause step by step

- Work every fault through the eight steps below in order, because skipping steps is how a symptom gets mistaken for a cause.

- Step 1, pin the symptom down in writing before touching anything.

  - Record the user's own words, the user id and username, the token name, the model, the request format and path, the client, the exact error text or status code and the time window.
  - Convert the window from Beijing time to unix seconds for `logs.created_at`, and write both forms into the notes.
  - Ask the user only for what the data cannot show, such as which client he used, and pull everything else yourself.

- Step 2, measure the scope before forming any theory.

  - Count the affected rows and the total rows in the same window, and state the share.
  - Find the first affected row and check whether the fault is still happening in the most recent hour.
  - Group the affected rows by channel, by model, by user and by format, because the dimension the fault follows points at the layer that owns it.
  - Read a fault on one channel across many users as a channel or upstream fault, a fault on one user across many channels as an account or token fault, and a fault on one format across channels as a format handling fault.

- Step 3, pull the evidence in a fixed order and know what each source can prove.

  - Read the `users` row for quota state, the `tokens` row for group and limits, and the grouped `logs` rows for what actually happened.
  - Read `other.admin_info` on suspect log rows for the billing path, the routing attempts and the local counting flag.
  - Read the `channels` row for type, status, group, models and `model_mapping`, and read `options` for `GroupRatio`, the billing expression and the usable groups.
  - Read `abilities` when a model should be visible or routable, and read the journal or nginx log only for service level faults such as a 502 or a dead process.
  - Treat each source as proof only for its own layer, because a log row proves the charge and never proves why the upstream answered as it did.

- Step 4, write the hypotheses before running any test.

  - Cover at least four families every time, covering the upstream, the relay code, the configuration and pricing, and the client behaviour.
  - Write beside each hypothesis the one test that would separate it from the rest and the result that family predicts.
  - Drop a hypothesis only when its predicted result fails, and say which test dropped it.

- Step 5, run the cheapest separating test first and change one variable at a time.

  - Call the suspect upstream directly on the host with the channel's own key, once in OpenAI format and once in Claude format, keeping the prompt identical.
  - Run a control on a healthy channel with the same model and the same format, because a working control turns a guess into a comparison.
  - Vary stream against non stream, or a small prompt against the user's real prompt size, only after the format comparison is clear.

- Step 6, reconcile the money whenever a charge is in dispute.

  - Sum the disputed log rows and compare the sum with the movement in `users.used_quota` over the same window.
  - Recompute what the rows should have cost from the live billing expression and the group ratio, and show both numbers and the difference.
  - Name the rows that cannot be recomputed and say why, instead of folding them into the difference.

- Step 7, state the verdict in three buckets.

  - Put direct test results and reconciled numbers under confirmed, put pattern matches under inference and label them as inference, and put everything untested under unknown with the test that would settle it.
  - Never promote a pattern match to confirmed, because a signature that matched twice can still have a second cause the third time.

- Step 8, give the fix as a doable plan, not as advice.

  - Write each fix option with its concrete steps, its tier, the users and models it affects, its rollback and the exact measurement that will prove the fix worked.
  - Back up first and get approval for any tier 3 fix, then apply the smallest option the user chose.
  - Rerun the step 2 measurement over the same length of window after the fix and put the before and after numbers side by side in the report.

- Read `~/workspace/custom-skills/madfu-manager/references/examples.md` before a similar investigation, because six past cases there show this method with their real numbers and their dead ends.

## Render reports as HTML pages

- Render every formal report through the answer-me-with-html skill, because the user added that rule on 2026-10-20.

- Read `~/workspace/custom-skills/local-answer-me-with-html/SKILL.md` before rendering, because that skill owns the format and its rules override any habit of writing HTML by hand.

- Write only the extended Markdown content draft and let the `am` CLI build the page, and never hand write HTML, CSS or SVG for a report.

- Render with `node "$HOME/workspace/skills/answer-me-with-html/scripts/am.mjs" render - --no-open` and feed the draft on stdin, because the global `am` alias can be missing from a non interactive shell.

- Fix every draft line the STE check flags and render again, and keep the final page at zero STE warnings when a small wording change achieves it.

- Render these report types as pages, covering a health check anomaly, a complaint investigation, a channel or pricing change and an upgrade or backup result that needs more than a few lines.

- Answer short questions and all OK results in plain chat text, because a page for a one line result only adds work for the reader.

- Put the verdict in the first panel as a callout and put the measured numbers in a table that names the window and the method.

- Split facts, inferences and unknowns into separate panels and end with the decisions that wait for the user, including the tier of each fix.

- Keep keys, passwords, hashes and full tokens out of the draft, because the page can be saved and shared outside this chat.

- Deliver the finished single file page to the user with a chat summary of two or three lines, conclusion first, and never paste the full report into chat.

## Apply the billing facts that are already proven

- Write per call prices only as `tier("base", fixed(0.008))` style expressions, because `tier("base", 0.008)` silently charges zero and a bare `fixed(...)` raises `model_price_error`.

- Calculate a grouped model's real price as its `billing_expr` result multiplied by the group's `GroupRatio`, because the ratio lives in `options` under `GroupRatio` and is cached in memory.

- Restart `newapi` after any `GroupRatio` or billing expression change and then verify, because the running process keeps the old cached values until it restarts.

- Treat vendors as display labels only, because a vendor never changes a price, a route or a permission.

- Send a model through a different channel at a different price by publishing a distinct model name and mapping it back to the real model in that channel's `model_mapping`, because pricing follows the published model name.

- Check both auth gates when a token gets a 403, because a non empty token `group` must appear in the user's usable groups and in `GroupRatio` or the API rejects it.

- Never put a vendor or supplier name into a token's `group`, because that name is not a real group and it caused a `/v1/models` 403 in production.

## Handle channels and request formats

- Test a channel directly against its upstream on the host when a format is in doubt, sending one OpenAI format and one Claude format request with the channel's own key, because the comparison separates an upstream fault from a relay fault.

- Test only when adding a channel, changing one or chasing a complaint, because the user wants no scheduled channel tests and every test call costs real money.

- Expect channel 19, the Sub2API type channel named 国模 C1.2 企业, to return an empty `content` array for Claude format requests while its OpenAI format works, because its upstream Claude endpoint is broken, not the relay.

- Expect streamed requests on channel 13 that end with zero completion tokens to fall back to local token counting at full prompt price with no cache discount, because that fallback is the proven root of the 2026-10-18 overcharge case.

- Recognise that fault by its signature in `logs`, zero `completion_tokens` rows concentrated on one channel and model with `local_count_tokens` in `other`, and quantify the affected calls and quota in the report instead of estimating.

- Leave the channel 13 fix and its cache discount undecided in this skill, because the expression change is a pricing decision the user has not made.

- Follow the user's supplied data when adding a channel, collecting the upstream name, base URL, key, model list, his cost, his selling price or ratio and the group before starting, and ask once for anything missing.

- Verify a new or changed channel with one small real call per format it will serve, then confirm the log row landed on the right channel and the test user's `used_quota` moved by the expected amount, and report the test cost.

## Back up, upgrade and roll back

- Pull backups with `~/workspace/custom-skills/madfu-manager/scripts/backup-pull.sh`, because it snapshots the live database on the host through the SQLite backup API, pulls the snapshot to `~/workspace/newapi-backups`, verifies the hash and `quick_check`, and deletes pulled copies older than 3 days.

- Treat pulled copies as secrets, because the database holds channel keys and password hashes, so never upload, share or commit one.

- Take a fresh pulled backup before any tier 3 database write and before any upgrade, because the 3 day retention leaves no older fallback.

- Back up the binary as `new-api.bak_<version>` beside the original during an upgrade and confirm the old process is fully stopped before swapping files.

- Reload nginx after any site change and verify an upgrade with service active, local `:3000/api/status` at 200, the nginx HTTPS path at 200 and database `quick_check` at ok.

- Check DNS resolution on the host when certificate issuance fails, because a broken `systemd-resolved` upstream has blocked certbot on these hosts before.

## Respect the standing decisions

- Keep NewAPI on the Hong Kong host and do not propose migrating it, because the user settled that on 2026-10-18.

- Keep the peak valley package at `~/workspace/newapi-peak-valley` undeployed, because its hours and ratios are still the user's to set and its server side cron must be written in UTC.

- Raise the DDoS choice and other already presented decisions no more than once, because the user decides them on his own schedule.

- Report an anomaly found during any other work, because exception only reporting still applies outside a health check.

## Available connectors

- Use `muse.connector_search` to find connector docs before using any connected service for this work.

- Use `muse.skill_search` to find related skills, and read the closest one before improvising a method.
