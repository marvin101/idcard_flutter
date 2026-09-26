"""Generate contain-fit CampusID platform icons from the canonical logo."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/images/campusid_logo.png"
BACKGROUND = (248, 243, 233, 255)


def square_icon(source: Image.Image, size: int) -> Image.Image:
    output = Image.new("RGBA", (size, size), BACKGROUND)
    logo = source.copy()
    logo.thumbnail((int(size * 0.82), int(size * 0.82)), Image.Resampling.LANCZOS)
    output.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2))
    return output


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    targets = {
        "web/favicon.png": 32,
        "web/icons/Icon-192.png": 192,
        "web/icons/Icon-512.png": 512,
        "web/icons/Icon-maskable-192.png": 192,
        "web/icons/Icon-maskable-512.png": 512,
        "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
        "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
        "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
        "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
        "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative, size in targets.items():
        square_icon(source, size).convert("RGB").save(
            ROOT / relative, "PNG", optimize=True
        )

    for relative in (
        "ios/Runner/Assets.xcassets/AppIcon.appiconset",
        "macos/Runner/Assets.xcassets/AppIcon.appiconset",
    ):
        for path in (ROOT / relative).glob("*.png"):
            size = max(Image.open(path).size)
            square_icon(source, size).convert("RGB").save(path, "PNG", optimize=True)

    windows = square_icon(source, 256)
    windows.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(16, 16), (32, 32), (48, 48), (256, 256)],
    )


if __name__ == "__main__":
    main()
