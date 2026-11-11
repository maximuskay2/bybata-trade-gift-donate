# BYBATA Living Stage

One screen per item. The photo stays. The task finishes on top of it.

Watched frame by frame:

- `~/Downloads/-7209530547531332354.MP4` — 33s, “How 10k$ App Looks Like”. Flutter, `main.dart`, iPhone 17 Pro. A sandal on a black stage.
- `~/Downloads/205376388735155207.MP4` — 13s. Flutter, `main.dart` / `screens/home_screen.dart`. A Starbucks drink from browse to “order ready”.

Both are the same product idea. Nothing in them is a tab, a route push, a glass grid, or a physics sandbox. The earlier glass / magnetic-drag / laser-camera plan does not match these films. This document replaces that plan.

APIs, PostgreSQL, and the Nest contracts stay as they are. Providers stay the source of truth: `TradeBackendProvider`, `GiftProvider`, `CampaignProvider`, `KarmaProvider`, `WalletProvider`.

## What the sandal film does

One black route. The sandal never unmounts.

1. A small gold ring in the center holds the product. It scales up until the sandal fills the stage. That ring is the transition from a thumbnail.
2. A finger drag pulls the sandal apart. Sole, strap, and shadow separate (`onPanUpdate`, a `_flying` offset, `lerpDouble` on left / top / size — the code is visible in the simulator). Release eases the parts back together.
3. Scroll is the only “next page”. The sandal stays pinned and changes scale and position while type arrives around it: **BEYOND LIMITS**, then **PRECISION CRAFTED**, then stat chips. Chapters, not routes.
4. The title chapter is **SANDAL 360°** plus a short story, still the same object, with a `< BACK` chip.
5. A white semicircle labeled **DISCOVER MORE** sits on the bottom edge. Dragging it up covers the stage with a light sheet (Full 360, HiDPI, 30fps, and a “back to experience” line). The black stage is still underneath. Dismiss returns to the rotating sandal.

Chrome is a logo chip and a wordmark. No tab bar. No list.

## What the drink film does

One route. The cup is the screen.

1. Full-bleed brand green. The drink floats in a soft radial glow. The previous and next drinks peek in from the left and right edges.
2. A white card is docked over the lower half. It shows one price (`$11`, `345ml`), the name, and a black **Get it** pill. The cup overlaps the top of the card. Horizontal swipe swaps drink, price, and title together. The card does not navigate.
3. **Get it** morphs this same screen into the builder. Background goes white. A huge faded **STARBUCKS** sits behind the cup. Title becomes **Cobbler / strawberry**. A vertical size rail sits on the left (three cup icons). A heart sits on the right. Price updates in place (`$13.00` Tail → `$14.50` Grande).
4. A bag is anchored at the bottom with the words **Swipe Down**. Delivery and Pickup are small icons, not a new step. Swiping the cup down drops it into the bag. The cup leaves. The bag stays.
5. Success is the same screen, emptied of the form: the wordmark, one line (“Your order will be ready shortly”), a green check, and the bag with the mark on it. No receipt page.

## The pattern to copy

| Beat | Sandal | Drink | Bybata |
| --- | --- | --- | --- |
| Enter | Thumbnail ring grows into the hero | Already on the hero; neighbors peek | Tapped card’s photo expands to a full-bleed stage |
| Stay | Object remains while copy scrolls | Object remains while the card changes | Photo remains while story, offer, claim, or pledge happen |
| Choose | Drag to explode the object | Vertical size rail, price reticks | Trade: your item rail. Donate: amount rail. Gift: one note |
| Commit | Pull the bottom semicircle | Swipe the object down into the bag | Swipe the photo down into the hub mark |
| Done | Sheet dismisses, object still there | Green check on the same screen | Check on the same screen, then the photo shrinks back into the grid |

Hub color fills the stage. Trade uses `AppTheme.tradeColor`, gift `AppTheme.giftColor`, donate `AppTheme.donationColor`. Success green is `AppColors.success`.

## Trade

`TradeScreen` browse stays the lobby. Tabs collapse to a quiet filter chip (Browse / Mine / Activity). Activity holds drafts, offers, and history. Five equal pills fight this layout.

**Open.** The tapped photo is the gold ring. It scales to full bleed on the trade color. Neighbors peek at the edges. A horizontal swipe changes listing, title, and owner together, using the list already loaded. No `TradeDetailsScreen` push from inside the hub. Deep links still use `TradeDetailsLoader`, and if the hub is up they open this stage.

**Docked card.** White rounded card over the lower half. One line for the title, one line for the owner and trust, one black pill: **Offer this** or **Edit** if it is yours. The photo overlaps the card.

**Scroll chapters**, same stage, photo pinned and shrinking as the user scrolls:

1. Hero and title.
2. Story, place, what they want in return.
3. Photos. A horizontal drag on the hero fans the photos apart the way the sandal splits, then eases them back. That is the media gallery.

**Discover.** A semicircle on the bottom edge reads **Details**. Dragging it up opens owner, trust, location, and similar trades in a sheet. **Back to item** dismisses it. The photo is still underneath.

**Offer, on this screen.** **Offer this** morphs the stage the way **Get it** does.

- Their photo stays centered.
- The left rail is the user’s own listings (`ItemSelectionWidget` turned vertical, same role as the cup-size rail). Tapping one parks a small copy of it under the hero. Price or BYC difference reticks under the photo the way `$13.00` becomes `$14.50`.
- If a top-up is required, `EvenTradePanel` appears as a single row under the number. It does not push.
- The bottom anchor is a swap mark labeled **Swipe down to offer**.
- Swiping the hero down runs the existing `TradeBackendProvider` submit. On success the form clears and the same screen shows **Offer sent**, one green check, and the swap mark. `HapticUtils.heavy` once. Failure keeps the form and uses `HapticUtils.error` plus `AppToast`.
- Chat is still `TradeChatScreen`. A message icon pushes it and returns to this offer stage.

## Gift

Same shell on `GiftingScreen`, gift color.

Docked card: title, giver, **Request**. Scroll chapters: story, photos (fan on drag), place. Semicircle **Details** for the claim rules.

**Request** morphs in place. The only extra field is the note already in `GiftClaimSheetContent`. The bottom anchor says **Swipe down to request**. The swipe calls `GiftProvider`. Success copy is **Request sent**, green check, gift mark. Karma marks fly to the badge only when `KarmaProvider` reports a real delta. Eight marks, then gone. No delta, no marks.

`openGiftGiverChat` still pushes chat and returns here.

## Donate

Same shell on `DonationsScreen`, donate color.

Docked card: title, **raised / goal** as the one number, **Give**. The browse grid keeps flat bars. The wave is not the film. The film’s feedback is the big number changing.

**Give** morphs in place. The left rail is the amounts already in `DonationBottomSheet`: `10, 25, 50, 100, 250, 500`, plus a custom row. Selecting one reticks the number to the draft total and labels it as a preview. Note, anonymous, and reward tier sit in one short scroll under the number, not a second page. Balance comes from `WalletProvider`. The iOS campaign check stays.

Bottom anchor: **Swipe down to give**. Success, only after the provider confirms: **Thank you**, the new raised amount, green check. If that confirmation crosses 100%, the check plays once per campaign per session. The border does not loop.

## Create, as the film run backwards

The side rail on trade and gift, and the campaign create entry, expand an empty stage in the hub color.

1. Add photo. It flies to center the way the ring grows.
2. Scroll chapters are the three steps that already exist (`ListingCreateShell` / `EnhancedStepper`): trade What & photos, Story & place, Preferences; gift Basics, Details, Review; campaign Basics, Story & goal, Launch. The stepper becomes a chapter index, not a new route.
3. The bottom semicircle is **Review**.
4. **Swipe down to publish** calls the current create method. Success is **Listed** or **Live**, a green check, then the photo shrinks back into the top of the grid.

Drafts still save. Validation messages stay on the chapter that failed.

## The picture and the video have to come out clean

The sandal and the drink have no room behind them. A photo of an item on a bed, a table, or a floor breaks that stage. Tips on a card will not fix it. `ListingMediaUploadGuidance` already tells people to crop to 16:10, and `ImageCropUtils` then locks that crop. The background stays in the file.

Trade, gift, and donation already share `ListingMediaPicker` and `EditableListingMediaPicker` (`cameraOnly` defaults to true). Create and edit for all three go through that picker, then `ListingMediaUploadService` stores the file under the existing `mediaKeys` or `videoKey`. The fix belongs in the picker, once, so every post gets it. No new column and no new upload field. The edited JPEG replaces the file those keys already point at.

### What “the right take” means

The phone camera opens inside the app, on the hub color, with a frame drawn where the item must sit. The system camera sheet is no longer the capture UI. The shutter stays off until all of these are true:

- The item sits inside the frame, with space around it. A cutout that touches the edge frays.
- The shot is bright enough. A dark frame is rejected before the mask runs.
- The phone is steady for a short moment. A moving shot is rejected.
- After the mask, one subject covers roughly a quarter to four fifths of the frame. A tiny item, a full-bleed wall, or two big objects fails.

The failure is a sentence on the preview, not a generic error: “Step back so the whole item is inside the frame”, “Add light”, “Hold still”, or “Show one item”. **Use original** is not a choice. Continue on the media step stays disabled until every photo has passed.

Gallery import, where a flow still allows it, runs the same mask and the same refusal.

### What the edit does to a photo

On shutter, the app lifts the subject off the background on the device. iOS uses the Vision foreground mask. Android uses ML Kit subject segmentation. One Dart class hides that split.

The cutout is placed in the middle of a flat field in the hub color, with a soft shadow under it, then saved as a JPEG. That JPEG is what gets uploaded. Feed cards stay 16:10 because `ImageResizeUtils` still letterboxes this cutout into `ListingMediaConstants.feedAspectRatio`. The hero stage shows the same pixels, so the card and the stage match. The room is gone. The user sees that result full screen and taps **Use this** or **Retake**. There is no crop screen and no background slider.

A mask that comes back ragged, empty, or touching the edges is a retake. The original is discarded.

### What the edit does to a video

A one-minute clip with the background removed on the phone will not hold up, and the stage does not need a minute. The hero clip becomes **8 seconds**. `VideoProcessingUtils.maxDuration` is 60 seconds today. New hero clips use 8. Older uploaded videos keep playing as they are.

Record UI matches the photo frame. The line on screen is “Keep the item in the frame and turn it slowly.” The shutter refuses to finish the clip if the item leaves the frame or the phone is whipping around.

On stop:

1. A poster frame goes through the same photo cutout. That poster is the resting hero and the feed thumbnail (`thumbnailKey` already exists).
2. The clip is center-cropped to the subject’s box, sampled a few times across the 8 seconds and smoothed, then compressed the way `prepareForUpload` already compresses. The room is cropped down, not painted away frame by frame.
3. The stage shows the cutout poster. The clip plays only when the user taps the hero, inside that same frame.

Full video matting (a transparent clip) is a later server job on that short file. Posting does not wait for it. Until it exists, the hero never shows the raw room video as its resting image.

### Where it lands in the build

The picker change is the whole feature. The three create screens do not each grow a camera.

This part is in the app now. `ListingMediaPicker` and `EditableListingMediaPicker` open `HeroCapturePage`, then `prepareStagePhoto`. A still is refused for light, blur, or a subject that touches the edge, then cut out with `native_cutout` and saved as the upload JPEG by `StageImage`. The shutter stays off until the preview is bright, still, and the center has more detail than the edges. New clips are capped at 8 seconds. The poster goes through the same cutout. A take stops early if the phone whips or a sampled frame loses the item. A steady subject is cropped to one smoothed box and then compressed. If the device cannot crop, the compressed original is kept. The clip is not matted frame by frame. Whip detection uses the platform motion channel, not a new package. iOS needs a real device on iOS 17 or newer. Android downloads the ML Kit model once through Google Play. Those device paths were not run in this pass.

| Gate | Photo | Video |
| --- | --- | --- |
| Frame | Item inside the guide, margin around it | Same guide for the whole take |
| Light and stillness | Shutter off until both pass | Recording stops early if the item leaves the frame |
| After capture | One subject, cut out, placed on the hub color | Poster cut out the same way. Clip cropped to the subject |
| If it fails | Retake. Original is not kept | Retake. Original is not kept |
| What is stored | Edited JPEG in `mediaKeys` | Cropped MP4 in `videoKey`, cutout poster in `thumbnailKey` |

## What we are not building

- A glass grid, mesh gradient, gyroscope, or blur on every card. These films use a flat brand field and one soft glow behind the photo.
- Dragging two browse cards together. The only drag is on the open hero (fan the photos) and the swipe-down commit.
- A laser scanner or a “verified live” stamp. The camera guide below is only there to frame the item. The stamp after publish says **Listed** or **Live**. Trust keeps `verified_badge.dart`.
- Rive, Skia, sensors, or a physics package. The sandal source on screen is `GestureDetector`, `AnimatedBuilder`, `Tween`, and `lerpDouble`. `flutter_animate` is already in `pubspec.yaml` for the small fades.
- Particles as the main event. The success symbol is a check on the same screen.

`MediaQuery.disableAnimationsOf` skips the fly, the fan, and the drop, and crossfades in 150 ms. The swipe-down control is also a button, so the action is available without the gesture.

One `BackdropFilter` at most, on the details sheet only, and only while glass mode is on. `ByBataGlassContainer` already has the solid fallback.

## Engineering

```
lib/core/motion/hero_stage.dart       full-bleed color, neighbor peek, docked card, bottom anchor
lib/core/motion/stage_controller.dart chapter index, builder open, focusId
lib/core/motion/swipe_commit.dart     swipe-down threshold, button fallback, reduce-motion
```

`TradeDetailsScreen`, `GiftDetailsScreen`, and `CampaignDetailsScreen` expose the body the stage scrolls. A deep link opens the stage when that hub is already the visible route. Otherwise the existing detail loader stays. Create screens stay their own routes. The hub rail scales an empty hub-colored stage into `ListingCreateShell`.

`StageController` stores what is open. Field values stay in the create screens and the providers.

Back order:

1. Success check dismisses to the hero.
2. Builder closes back to the docked card.
3. Details sheet closes.
4. Hero shrinks into the card that opened it.
5. Then the hub route pops.

Tests with each slice:

- Horizontal swipe changes `focusId` and does not push a route.
- Size or amount rail changes the displayed number and not the saved listing.
- Swipe past the commit threshold calls the existing submit once. A short swipe springs the photo back.
- Reduce motion: the button still submits, no fly or drop.
- Failed submit leaves the builder filled in.

## Slices

1. **In the app.** `LivingHeroStage` on a trade item. Photo, docked card, neighbor peek, scroll chapters. Browse and Mine open the stage instead of `TradeDetailsScreen`. A deep link opens that stage when the hub is already visible. Otherwise it still uses `TradeDetailsLoader`.
2. **In the app.** Trade offer builder and swipe-down call `TradeBackendProvider.createOffer`. A failed offer leaves the note and the selected item. Chat still pushes `TradeChatScreen` and returns here.
3. **In the app.** Trade create keeps its three steps as chapter captions. The last step is **Swipe down to publish**, which calls `_submitTrade`.
4. **In the app.** Gift hero, note (and claim code when the gift needs one), swipe-down through `GiftProvider.claimGift`. Success copy is **Request sent**. Karma marks fly only after `KarmaProvider` reports a higher total.
5. **In the app.** Donate hero, amount rail `10, 25, 50, 100, 250, 500`, swipe-down through `CampaignProvider.donateToCampaign`. Success copy is **Thank you** plus the confirmed raised amount. The 100% check plays once per campaign per session. iOS still leaves the app for web support.
6. **In the app.** Campaign create uses the same chapter caption and swipe-down publish. Hub chrome is Browse / Mine / Activity. The old history buttons switch that deck instead of pushing `MyTradesScreen`, `MyGiftsScreen`, and `DonationHistoryScreen`.
7. **In the app.** A home bento tap opens the matching hub with `stageFocusId`, and that hub opens `LivingHeroStage` on the item. Search stays as it is.

The picture gate from the section above is already in the picker. New stills are cut out before upload. New clips are capped at 8 seconds, stopped early when the take leaves the frame, and cropped to the subject when the device can. The clip itself is not matted frame by frame.

8. **In the app.** The shutter stays off until light, stillness, and a centered subject pass. A whip or a lost subject stops the clip. The file is cropped to the smoothed subject box, then compressed. A missing crop keeps the compressed original. Not run on a phone.
9. **In the app.** A tapped card grows a gold ring to the hero and shrinks back into that card. Commit drops the photo into the mark. A horizontal drag on the gallery fans the photos. The details list is labeled Similar.
10. **In the app.** The create rail scales into an empty hub-colored stage. Review is the bottom semicircle. Publish shows Listed or Live, a green check, then the photo shrinks away. Edit trade, gift, and campaign save with swipe down.
11. **In the app.** Trade, gift, and campaign links open the stage when that hub is the visible route. Chat, search, and profile still push the detail loader.

## Acceptance

From a hub, with no route transition, a person can:

- Swipe across listings, read the story by scrolling, open details from the bottom semicircle, and close it back onto the photo.
- Trade: pick one of their items, see the difference retick, swipe down, and read **Offer sent** on that screen.
- Gift: add a note, swipe down, and read **Request sent**.
- Donate: pick an amount, watch the number change, swipe down, and read the confirmed amount.
- Create: add a photo, pass the three chapters, swipe down, and land back on the new card.

Chat, PayPal top-up, sign-in, guest browse, dark mode, and reduce-motion still behave. Payloads are unchanged.
