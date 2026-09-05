const WINDOWHOP_SITE = Object.freeze({
  version: "2.0.0",
  website: "https://zhangqiaoran.github.io/windowhop-optimized/",
  github: "https://github.com/zhangqiaoran/windowhop-optimized",
  issues: "https://github.com/zhangqiaoran/windowhop-optimized/issues",
  releases: "https://github.com/zhangqiaoran/windowhop-optimized/releases",
  releaseNotes: "https://github.com/zhangqiaoran/windowhop-optimized/releases/tag/v2.0.0",
  download: "https://github.com/zhangqiaoran/windowhop-optimized/releases/latest/download/my-alt-tab-2.0.0.zip",
  license: "https://github.com/zhangqiaoran/windowhop-optimized/blob/main/LICENSE",
  altTab: "https://github.com/lwouis/alt-tab-macos",
});

document.querySelectorAll("[data-link]").forEach((link) => {
  const destination = WINDOWHOP_SITE[link.dataset.link];
  if (destination) link.href = destination;
});

document.querySelectorAll("[data-site-version]").forEach((element) => {
  element.textContent = WINDOWHOP_SITE.version;
});

document.querySelectorAll("[data-site-year]").forEach((element) => {
  element.textContent = new Date().getFullYear();
});