package Diablo

import dgengine.*

func registerHooks(): Unit {
    Hooks.decodeImage = loadImagePCX
    Hooks.getImageContainerObj = getImageContainerObj
    Hooks.parseTextureImg = parseTextureImg
    Hooks.registerArchivers = registerMPQArchiver
    Hooks.archiveExtensions = [".zip", ".7z", ".mpq"]
}
