module.exports = {
  action: "inject",
  apiAuth: false,
  delay: 10,
  duplicateCategories: true,
  flatLinking: true,
  fuzzySizeThreshold: 0.02,
  includeEpisodes: true,
  includeNonVideos: false,
  linkCategory: "cross-seed",
  matchMode: "safe",
  notificationWebhookUrl: `$${process.env.CROSS_SEED_WEBHOOK_URL}`,
  outputDir: "/config",
  qbittorrentUrl: "http://qbittorrent.media.svc.cluster.local",
  rssCadence: "60min",
  searchCadence: "7d",
  torrentDir: "/qbittorrent/qBittorrent/BT_backup",
  torznab: [
    `http://prowlarr.media.svc.cluster.local/19/api?apikey=$${process.env.PROWLARR_API_KEY}`,
    `http://prowlarr.media.svc.cluster.local/31/api?apikey=$${process.env.PROWLARR_API_KEY}`,
    `http://prowlarr.media.svc.cluster.local/20/api?apikey=$${process.env.PROWLARR_API_KEY}`,
    `http://prowlarr.media.svc.cluster.local/28/api?apikey=$${process.env.PROWLARR_API_KEY}`,
    `http://prowlarr.media.svc.cluster.local/21/api?apikey=$${process.env.PROWLARR_API_KEY}`
  ],
};


//# sourceMappingURL=config.template.docker.cjs.map
