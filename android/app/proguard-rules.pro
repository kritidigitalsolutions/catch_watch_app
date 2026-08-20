# Ignore missing push SDKs referenced by Hyphenate
-dontwarn com.heytap.msp.push.**
-dontwarn com.meizu.cloud.pushsdk.**
-dontwarn com.vivo.push.**
-dontwarn com.xiaomi.mipush.sdk.**
-dontwarn com.hyphenate.push.**

# Keep Hyphenate classes to prevent issues with reflection/obfuscation
-keep class com.hyphenate.** {*;}
-keep interface com.hyphenate.** {*;}
-dontwarn com.hyphenate.**
