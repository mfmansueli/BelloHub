# Apple root certificates (H14)

Put Apple's public root certificates here, DER encoded (`.cer`), downloaded from
https://www.apple.com/certificateauthority/ (at least `AppleRootCA-G3.cer`; `AppleIncRootCertificate.cer` and
`AppleRootCA-G2.cer` do no harm). They are public, so they are committed and deployed with the functions.

While this folder has no `.cer` file the server answers `NOT_CONFIGURED` to `syncPlan` and 503 to App Store
notifications, and every plan stays `none`. For Production also set `APPLE_ENVIRONMENT=Production` and
`APPLE_APP_ID=<numeric app id from App Store Connect>` in `functions/.env.<project>`.
