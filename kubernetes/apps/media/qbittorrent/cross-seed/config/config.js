module.exports = {
    delay: 10,
    torznab: [
      `http://prowlarr.media.svc.cluster.local/19/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local/31/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local/20/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local/28/api?apikey=$${process.env.PROWLARR_API_KEY}`,

      `http://prowlarr.media.svc.cluster.local/21/api?apikey=$${process.env.PROWLARR_API_KEY}`
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
    rssCadence: "60min",
    searchCadence: "7d",
};

//# sourceMappingURL=config.template.docker.cjs.map
