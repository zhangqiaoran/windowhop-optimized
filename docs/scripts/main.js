const WINDOWHOP_SITE = Object.freeze({
  version: "3.0.0",
  website: "https://zhangqiaoran.github.io/my-alt-tab/",
  github: "https://github.com/zhangqiaoran/my-alt-tab",
  issues: "https://github.com/zhangqiaoran/my-alt-tab/issues",
  releases: "https://github.com/zhangqiaoran/my-alt-tab/releases",
  releaseNotes: "https://github.com/zhangqiaoran/my-alt-tab/releases/tag/v3.0.0",
  download: "https://github.com/zhangqiaoran/my-alt-tab/releases/latest/download/my-alt-tab-3.0.0.zip",
  license: "https://github.com/zhangqiaoran/my-alt-tab/blob/main/LICENSE",
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