package Diablo

import dgengine.*
import stdx.encoding.json.*

private enum ImageContainerType {
    | ImageContainerUnknown
    | ImageContainerCEL
    | ImageContainerCL2
    | ImageContainerDC6
    | ImageContainerDCC
    | ImageContainerDT1
}

private func getImageContainerType(fileName: String, elem: JsonValue): ImageContainerType {
    var fileType = String.empty

    if (let Some(str) <- getValidString(elem, "type")) {
        fileType = str.toAsciiLower()
    } else {
        fileType = FileUtils.getFileExtension(fileName).toAsciiLower()
    }

    if (fileType.startsWith('.')) {
        fileType = fileType[1..]
    }

    return match (fileType) {
        case "cel" => ImageContainerCEL
        case "cl2" => ImageContainerCL2
        // case "dc6" => ImageContainerDC6
        // case "dcc" => ImageContainerDCC
        // case "dt1" => ImageContainerDT1
        case _ => ImageContainerUnknown
    }
}

func getImageContainerObj(fileBytes: Array<Byte>, fileName: String, elem: JsonValue): ?ImageContainer {
    match (getImageContainerType(fileName, elem)) {
        case ImageContainerCEL => CELImageContainer(fileBytes)
        case ImageContainerCL2 => CL2ImageContainer(fileBytes)
        // case ImageContainerDC6 => DC6ImageContainer(fileBytes)
        // case ImageContainerDCC => DCCImageContainer(fileBytes)
        // case ImageContainerDT1 => DT1ImageContainer(fileBytes)
        case _ => None
    }
}
