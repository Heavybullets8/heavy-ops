module.exports = {
    delay: 10,
    torznab: [
      `http://prowlarr.media.svc.cluster.local:9696/19/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local:9696/31/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local:9696/20/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local:9696/28/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local:9696/21/api?apikey=$${process.env.PROWLARR_API_KEY}`
    ],
    qbittorrentUrl: "http://qbittorrent.downloads.svc.cluster.local",
    matchMode: "safe",
    apiAuth: false,
    outputDir: "/config",
    torrentDir: "/qbittorrent/qBittorrent/BT_backup",
    includeEpisodes: true,
    includeNonVideos: false,
    fuzzySizeThreshold: 0.02,
    action: "inject",
    duplicateCategories: true,
    notificationWebhookUrl: `$${process.env.CROSS_SEED_WEBHOOK_URL}`,
    port: process.env.CROSSSEED_PORT || 2468,
    rssCadence: "60min",
    searchCadence: "7d",
};

//# sourceMappingURL=config.template.docker.cjs.map
