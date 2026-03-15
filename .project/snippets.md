# Create a surface/planet and go there
(Replace "vulcanus" with gleba, fulgora, or aquilo).

/c game.planets["vulcanus"].create_surface()
/c game.player.teleport({0, 0}, "vulcanus")

# Research all tech
/c game.player.force.research_all_technologies()