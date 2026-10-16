# Project Rules & Guidelines

## Dialogs & Popups (یاسای دیالۆگ و پۆپئەپەکان)

- **بەتنی داخستن لەسەرەوە لای چەپ (Top-Left Close Button)**:
  - لە هەموو دیالۆگ، پۆپئەپ و مۆدالەکاندا دەبێت بەتنی کڵۆس (Close icon button / `X`) لە سەرەوە لای چەپ هەبێت بۆ داخستن و پاشگەزبوونەوە.
  - Always place a close button (`IconButton` with `Icons.close`) at the top-left of the dialog/popup header.

- **قەدەغەکردنی بەتنی پاشگەزبوونەوە و داخستن لە خوارەوە (No Bottom Cancel/Close Buttons)**:
  - هەرگیز لە هیچ پۆپئەپێکدا بەتنی «پاشگەزبوونەوە» (Cancel)، «داخستن» (Close) یان بەتنی هاوشێوە لە بەشی خوارەوە (actions / bottom footer) دانانرێت.
  - لە بەشی خوارەوە تەنها بەتنی کرداری سەرەکی (وەک «بەڵێ، بسڕەوە»، «پاشەکەوتکردن»، «تەئکیدکردنەوە») دەمێنێتەوە ئەگەر پێویست بێت.
  - Never include cancel/close buttons (`پاشگەزبوونەوە`, `داخستن`, etc.) at the bottom actions/footer of any popup or dialog. Only the primary action button (e.g., confirm, save, delete) should be placed at the bottom if needed.

## Backend Modifications (دەستکاریکردنی باکێند)

- **ئاگادارکردنەوە لە دەستکاریکردنی فایلەکانی باکێند (Notify Backend Changes)**:
  - هەرکاتێک هەر دەستکاریەک، چاکسازیەک یان گۆڕانکاریەک لە کۆدەکانی بەشی باکێند (`backend/`) ئەنجامدرا، دەبێت ڕاستەوخۆ لە وەڵامەکەدا ناوی تەواو و ڕێڕەوی (Path) ئەو فایلانەی دەستکاری کراون بنووسرێت، بۆ ئەوەی بەکارهێنەر بتوانێت ئەو فایلانە بۆ هۆست (Server) بەرزبکاتەوە (Upload).
  - Whenever any change, fix, or modification is made to the backend files, always explicitly list the exact modified file paths in the response so the user can easily upload them to the hosting server.
