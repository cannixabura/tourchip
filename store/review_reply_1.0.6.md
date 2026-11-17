# 回覆 App 審查（1.0.6，Guideline 5.6）

Hello,

Thank you for the review. TourChip has no hidden features, and nothing in the app changes based on review status, date, region, device or any remote switch. Every feature is available to every user from the first launch. The 1.0.6 update only changes the layout of the panel under the map.

**Removed in build 18: our internal debug screenshot tool**
Earlier builds contained a debug-only tool that we used on the simulator to make App Store screenshots. It filled the screens with sample data. It was switched off in release builds and never ran on users' devices, but its code was still inside the binary. Build 18 deletes this tool and all of its code completely, so the binary you review is exactly what users get.

**Two-device screen recording**
We attached a screen recording of two devices side by side (left: leader, right: member). Each step has a caption at the top:
1. The leader starts a group (no account or login) and shows the join QR code and invite code.
2. The member taps "Join with invite code", enters the 8-digit code and joins.
3. The member agrees to share location inside the group and sees the leader on the map.
4. Gather: the leader drags the map to place the meeting point and sends it. The member gets the meetup card with countdown, distance and direction, and taps "Got it".
5. The member taps "I'll be late"; the leader sees it in the list.
6. Roll call: the member answers "I'm here" and the leader sees Here 1/1.
7. Live talk: the leader taps the microphone at the top and goes live; the member taps the headphone icon to listen.
8. The panel under the map folds (tap the handle or swipe down) and opens again. This is the only change in 1.0.6.

Many features are only visible inside a group, and some only appear when a second person joins. That may be why they looked hidden. Settings > Help also lists every feature and how to use it.

If anything else is unclear, we are happy to answer questions about any screen.

Thank you,
TourChip team
