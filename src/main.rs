use std::path::PathBuf;

use anyhow::{Context, Result, bail};

const APOD_URL: &'static str = "https://apod.nasa.gov/apod/";
#[cfg(target_os = "windows")]
const WALLPAPER_PATH: &'static str = "C:\\ProgramData\\Wallpaper\\apod";

fn main() -> Result<()> {
    let path = get_apod()?;
    set_wallpaper(path)?;

    Ok(())
}

fn get_apod() -> Result<PathBuf> {
    let Some(img_src) = reqwest::blocking::get(APOD_URL)
        .context("failed to get APOD html")?
        .text()
        .context("failed to decode APOD html")?
        .split('\n')
        .find(|line| line.starts_with("<IMG SRC=\""))
        .map(|line| APOD_URL.to_owned() + line.split('"').nth(1).unwrap())
    else {
        bail!("Unable to extract image source from APOD html");
    };

    let bytes = reqwest::blocking::get(img_src)
        .context("failed to get APOD")?
        .bytes()
        .context("failed to extract APOD body")?;
    let mut wallpaper_path = PathBuf::from(WALLPAPER_PATH);
    std::fs::create_dir_all(&wallpaper_path).context("failed to create wallpaper path")?;
    wallpaper_path.push("apod.jpg");
    std::fs::write(&wallpaper_path, bytes).context("failed to persist APOD image")?;

    Ok(wallpaper_path)
}

#[cfg(target_os = "windows")]
fn set_wallpaper(file: PathBuf) -> Result<()> {
    use std::iter;
    use std::os::windows::ffi::OsStrExt;
    use windows::Win32::UI::WindowsAndMessaging::{
        SPI_SETDESKWALLPAPER, SPIF_SENDCHANGE, SPIF_UPDATEINIFILE, SystemParametersInfoW,
    };

    let mut wide = file.as_os_str()
        .encode_wide()
        .chain(iter::once(0))
        .collect::<Vec<u16>>();

    unsafe {
        SystemParametersInfoW(
            SPI_SETDESKWALLPAPER,
            0,
            Some(wide.as_mut_ptr() as *mut _),
            SPIF_UPDATEINIFILE | SPIF_SENDCHANGE,
        )?;
    }

    Ok(())
}
