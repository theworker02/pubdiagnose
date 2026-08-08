# Rollback

Every applied repair writes pre-images under
`.dart_tool/pubdoctor/repair/<transaction>/`.

On verification failure, PubDoctor restores pre-images and records the outcome
in `history.jsonl` (`pubdoctor audit repair`).
