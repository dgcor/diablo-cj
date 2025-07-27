package Diablo

import cjsfml.graphics.*
import cjsfml.system.InputStream
import endian.*
import std.io.{ByteBuffer, SeekPosition}

// struct PCXImage {
//     let manufacturer: UInt8 // manufacturer
//     let version: UInt8 // version
//     let encoding: UInt8 // encoding type
//     let bitsPerPixel: UInt8 // number of bits per pixel

//     let x: UInt16
//     let y: UInt16
//     let width: UInt16
//     let height: UInt16
//     let horzRes: UInt16 // horizontal screen resolution
//     let vertRes: UInt16 // vertical screen resolution

//     let palette: VArray<UInt8, $48> // color palette
//     let reserved: UInt8 // reserved
//     let numColorPlanes: UInt8 // number of planes
//     let bytesPerScanLine: UInt16 // byte per line
//     let paletteType: UInt16 // palette type
//     let horzSize: UInt16
//     let vertSize: UInt16
//     let padding: VArray<UInt8, $54>
// }

func loadImagePCX(file: InputStream): ?Image {
    let fileSize = file.length
    if (fileSize < 900) {
        return None
    }

    let data = Array<Byte>(fileSize, repeat: 0)
    file.seek(Begin(0))
    file.read(data)

    let reader = LittleEndianReader(ByteBuffer(data))

    /////////////////////////////////////////////////////

    let manufacturer = reader.read<UInt8>() ?? 0
    let version = reader.read<UInt8>() ?? 0
    let encoding = reader.read<UInt8>() ?? 0
    let bitsPerPixel = reader.read<UInt8>() ?? 0

    if ((manufacturer != 10) || (version != 5) || (encoding != 1) || (bitsPerPixel != 8)) {
        return None
    }

    // the palette is located at the 769th last byte of the file
    let paletteStartPos = fileSize - 769

    // verify the palette; first byte must be equal to 12
    if (data[paletteStartPos] != 12) {
        return None
    }

    let headerX = reader.read<UInt16>() ?? 0
    let headerY = reader.read<UInt16>() ?? 0
    let headerWidth = reader.read<UInt16>() ?? 0
    let headerHeight = reader.read<UInt16>() ?? 0

    let palette = data[paletteStartPos + 1..]
    let width = UInt32(headerWidth) - UInt32(headerX) + 1
    let height = UInt32(headerHeight) - UInt32(headerY) + 1
    let imageSize = Int64(width) * Int64(height)

    let image = Image(width, height)
    let pixels = image.pixelsPtr

    // decode compressed image (RLE)
    var idx = 0
    var buffIdx = 128
    while (idx < imageSize && buffIdx < paletteStartPos) {
        var c = data[buffIdx]
        buffIdx++
        if (c > 0xbf) {
            let numRepeat = 0x3f & c
            c = data[buffIdx]
            buffIdx++

            for (_ in 0..numRepeat) {
                let palIdx = 3 * Int64(c)
                unsafe {
                    pixels.write(idx * 4 + 0, palette[palIdx + 0])
                    pixels.write(idx * 4 + 1, palette[palIdx + 1])
                    pixels.write(idx * 4 + 2, palette[palIdx + 2])
                }
                idx++
                if (idx >= imageSize) {
                    break
                }
            }
        } else {
            let palIdx = 3 * Int64(c)
            unsafe {
                pixels.write(idx * 4 + 0, palette[palIdx + 0])
                pixels.write(idx * 4 + 1, palette[palIdx + 1])
                pixels.write(idx * 4 + 2, palette[palIdx + 2])
            }
            idx++
        }
    }
    return image
}
