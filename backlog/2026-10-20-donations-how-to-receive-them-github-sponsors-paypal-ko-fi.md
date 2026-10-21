---
title: Donations: how to receive them (GitHub Sponsors, PayPal, Ko-fi, Polar); resume the discussion
kind: question
status: open
priority: normal
area: release, docs, ui
source: user
raised: 2026-10-20
raised_in: the user, 2026-10-20
---

## What

From the user (2026-10-20): the guide is to be freely available, with the option to donate "if they feel generous enough to do so". The user
lives in South Africa and banks with FNB. They expect "almost exclusively non-South African donors". They first wanted to skip PayPal "if
possible", then said "it seems like I will need to consider PayPal anyway" and asked for this to be written down so the conversation can be
picked up again later, **with PayPal in the discussion**. They want a link inside the addon and one on CurseForge; GitHub "maybe, that's still
open for discussion".

Nothing is decided about the channel. This item holds what the discussion of 2026-10-20 found, so that resuming it starts from facts. It comes
from GitHub's, Stripe's, Polar's, PayPal's, FNB's, Ko-fi's and CurseForge's own pages, some of them old: check every figure against the live
page before relying on it.

### The options

- **GitHub Sponsors.** South Africa is on GitHub's supported-region list. GitHub charges no fee on sponsorships from personal accounts. Payout is
  to a bank account in the region one lives in (through Stripe Connect) or via a fiscal host; it needs two-factor authentication on the GitHub
  account and a W-8BEN tax form. Donors need a free GitHub account and pay by card, once or monthly. **Not confirmed:** that GitHub can really
  pay out to an FNB account (Stripe's own self-serve cross-border payouts list only the US, UK, EEA, Canada and Switzerland); the application
  shows it, and it is free to try. It is the cheapest option and has the most friction for a WoW player (the GitHub account).
- **PayPal.** In South Africa PayPal funds can only be withdrawn through FNB's own withdraw service, within 30 days of receipt. Costs, adding up:
  PayPal's South Africa seller page lists 4.90% plus a fixed fee per payment; the conversion to rand is 2.5% above the exchange rate; FNB charges
  about 1.5% per withdrawal (tiered down to about 1% by volume). Another PayPal page lists a South African withdrawal fee of 2.0% + 1.50 USD, which
  may or may not apply when the withdrawal goes through FNB. By rough arithmetic that is about 14% of a $5 donation and 9 to 10% of $20 to $50.
  Make a small test payment to learn the real cost. Donors can pay by card or PayPal; no GitHub account.
- **Ko-fi.** A page where donors need no account. It has no payout system of its own: it pays out through PayPal or Stripe, and Stripe is not
  open to South African residents (South Africa is in Stripe's "extended network"; its local arm is Paystack), so for the user it means PayPal.
  Ko-fi's own pricing says its fee is at most 5% (Ko-fi Gold, $12 a month, removes it; some pages say plain tips cost nothing) plus the
  processor's fees.
- **Polar** (merchant of record, pays out through Stripe Connect Express, South Africa is on its payout list): 5% + 50 cents per payment on the
  free plan, 1.5% more on international cards, plus Stripe's payout fees: about 17% of a $5 donation. Probably only a fallback.
- **For South African donors** (few expected): a PayShap ShapID (created in the FNB app) or a SnapScan or Zapper QR; no conversion and no PayPal.
- **Not useful:** Buy Me a Coffee (payouts through PayPal or Stripe; South Africa unconfirmed), Patreon (higher fees), publishing the bank account.

### A starting point for the next conversation

With PayPal allowed: a Ko-fi page paid out through PayPal as the main link (no donor account needed), and GitHub Sponsors as the cheaper link
for those who have a GitHub account, both listed in the addon, on CurseForge and in `.github/FUNDING.yml`.

### Tax

Not advice: small gifts from unrelated supporters are usually not income, regular receipts for ongoing work can be. Ask a tax practitioner and
keep the statements.

## Why

The guide stays free and the player decides. Fees matter at small amounts, and the channel has to work for a South African recipient and for
donors anywhere else.

## Done when

- The conversation is picked up again and the user chooses the channel or channels (this item then records the choice).
- The user sets up the account(s): their GitHub, PayPal or Ko-fi identity, their bank details and tax form; Claude cannot do that part.
- `.github/FUNDING.yml` and the README link the donation page(s).
- The addon has a copyable link (the Journal window; an `ns.L` string; no pop-up, no nagging) and the CurseForge project has its donation
  method set (the user does that): modest, at the bottom of the page, and no feature only for donors (CurseForge's rules).
- One real test donation reaches the FNB account and the actual fee is written here.

## Notes

- User, 2026-10-21: "We can pick up the donations discussion on a different time." Nothing is to be built or decided until they raise it.
- CurseForge's own Rewards Program (points paid out through Tremendous in USD, EUR or GBP) is a different thing; whether a South African payout
  exists was not checked.
- Never publish the bank account number.
