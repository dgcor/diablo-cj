package Diablo

import cjsfml.graphics.*
import cjsfml.graphics.Image as SFMLImage
import dgengine.*
import endian.*
import std.collection.*
import std.io.{ByteBuffer, SeekPosition}

private enum CL2Type {
    | None
    | V2MonoGroup
    | V2MultipleGroups
}

// CL2 decoding code based on Diablo 1 Graphics Tool by savagesteel
// https://github.com/savagesteel/d1-graphics-tool
class CL2ImageContainer <: LazyImageContainer {
    private var m_directions: UInt32 = 0

    init(fileData: Array<Byte>) {
        super(fileData)

        var celType = V2MultipleGroups

        let fileStream = LittleEndianReader(ByteBuffer(fileData))

        // CL2 HEADER CHECKS

        // Read first DWORD
        let firstDword = Int64(fileStream.read<UInt32>() ?? 0)

        // Trying to find file size in CL2 header
        if (fileStream.length < (firstDword * 4 + 4 + 4)) {
            return
        }

        fileStream.seek(Begin(firstDword * 4 + 4))
        var fileSizeDword = fileStream.read<UInt32>() ?? 0

        // If the dword is not equal to the file size then
        // check if it's a CL2 with multiple groups
        if (fileStream.length != Int64(fileSizeDword)) {
            // Read offset of the last CL2 group header
            fileStream.seek(Begin(firstDword - 4))
            let lastGroupHeaderOffset = fileStream.read<UInt32>() ?? 0

            // Read the number of frames of the last CL2 group
            if (fileStream.length < Int64(lastGroupHeaderOffset)) {
                return
            }

            fileStream.seek(Begin(Int64(lastGroupHeaderOffset)))
            let lastGroupFrameCount = fileStream.read<UInt32>() ?? 0

            // Read the last frame offset corresponding to the file size
            if (fileStream.length < Int64(lastGroupHeaderOffset) + Int64(lastGroupFrameCount) * 4 + 4 + 4) {
                return
            }

            fileStream.seek(Begin(Int64(lastGroupHeaderOffset) + Int64(lastGroupFrameCount) * 4 + 4))
            fileSizeDword = fileStream.read<UInt32>() ?? 0
            // The offset is from the beginning of the last group header
            // so we need to add the offset of the lasr group header
            // to have an offset from the beginning of the file
            fileSizeDword += lastGroupHeaderOffset

            if (fileStream.length == Int64(fileSizeDword)) {
                celType = V2MultipleGroups
                m_directions = UInt32(firstDword / 4)
            } else {
                return
            }
        } else {
            celType = V2MonoGroup
            m_directions = 1
        }

        // CL2 FRAMES OFFSETS CALCULATION

        m_frameOffsets.clear()
        match (celType) {
            // Going through all groups
            case V2MultipleGroups =>
                var i = 0
                while (i * 4 < firstDword) {
                    fileStream.seek(Begin(i * 4))
                    let groupOffset = fileStream.read<UInt32>() ?? 0

                    fileStream.seek(Begin(Int64(groupOffset)))
                    let groupFrameCount = fileStream.read<UInt32>() ?? 0

                    // Going through all frames of the group
                    for (j in 1..=Int64(groupFrameCount)) {
                        fileStream.seek(Begin(Int64(groupOffset) + j * 4))
                        let frameStartOffset = fileStream.read<UInt32>() ?? 0
                        let frameEndOffset = fileStream.read<UInt32>() ?? 0

                        m_frameOffsets.add((groupOffset + frameStartOffset, groupOffset + frameEndOffset))
                    }
                    i++
                }
            // Going through all frames of the only group
            case _ => for (i in 1..=firstDword) {
                fileStream.seek(Begin(i * 4))
                let frameStartOffset = fileStream.read<UInt32>() ?? 0
                let frameEndOffset = fileStream.read<UInt32>() ?? 0

                m_frameOffsets.add((frameStartOffset, frameEndOffset))
            }
        }
    }

    private static func computeWidthFromHeader(frameData: Array<Byte>): UInt16 {
        var celFrameHeader = Array<UInt16>(5, repeat: 0)
        var celFrameWidth = Array<UInt16>(4, repeat: 0)

        // Read the {CEL FRAME HEADER}
        let fileStream = LittleEndianReader(ByteBuffer(frameData))

        for (index in 0..celFrameHeader.size) {
            celFrameHeader[index] = fileStream.read<UInt16>() ?? 0
        }

        // Read the five 32 pixel-lines block to calculate the image width
        var pixelCount = 0u16
        for (i in 0..4) {
            if (celFrameHeader[i + 1] == 0) {
                break
            }
            var j = celFrameHeader[i]
            while (j < celFrameHeader[i + 1]) {
                let readByte = UInt16(frameData[Int64(j)])
                if (readByte > 0x00 && readByte < 0x80) {
                    pixelCount += readByte
                } else if (readByte >= 0x80 && readByte < 0xBF) {
                    pixelCount += (0xBF - readByte)
                    j++
                } else if (readByte >= 0xBF) {
                    pixelCount += (256 - readByte)
                    j += (256 - readByte)
                }
                j++
            }
            celFrameWidth[i] = pixelCount / 32
            pixelCount = 0
        }

        // The calculated width has to be the identical for each 32 pixel-line block
        // If it's not the case, 0 is returned
        for (i in 0..3) {
            if (celFrameWidth[i + 1] != 0 && celFrameWidth[i] != celFrameWidth[i + 1]) {
                return 0
            }
        }
        return celFrameWidth[0]
    }

    public func decode(frameData: Array<Byte>, palette: ?PaletteArray): SFMLImage {
        var width = 0u32
        var frameDataStartOffset = 0i32

        if (frameData.size == 0) {
            return SFMLImage(0, 0)
        }

        // Checking the presence of the {CL2 FRAME HEADER}
        if (frameData[0] == 0x0A && frameData[1] == 0x00) {
            frameDataStartOffset += 0x0A
            // If header is present, try to compute frame width from frame header
            width = UInt32(computeWidthFromHeader(frameData))
        } else {
            return SFMLImage(0, 0)
        }
        if (width == 0) {
            return SFMLImage(0, 0)
        }

        let pixels = ArrayList<Color>(Int64(width) * Int64(width))

        // READ {CL2 FRAME DATA}

        var i = Int64(frameDataStartOffset)
        while (i < frameData.size) {
            var readByte = frameData[i]

            if (readByte > 0x00 && readByte < 0x80) {
                // Transparent pixels
                for (_ in 0..readByte) {
                    // Add transparent pixel
                    pixels.add(Color.transparent)
                }
            } else if (readByte >= 0x80 && readByte < 0xBF) {
                // Go to the palette index offset
                i++

                // Repeat palette index
                for (_ in 0..(0xBF - readByte)) {
                    // Add opaque pixel
                    pixels.add(ImageContainer.getColor(frameData[i], palette))
                }
            } else if (readByte >= 0xBF) {
                // Palette indices
                for (_ in 0..(256 - Int64(readByte))) {
                    // Go to the next palette index offset
                    i++
                    // Add opaque pixel
                    pixels.add(ImageContainer.getColor(frameData[i], palette))
                }
            } else if (readByte == 0x00) {
                // 0x00 found
            }
            i++
        }
        let height = UInt32(pixels.size / Int64(width))
        unsafe {
            let img = SFMLImage(width, height, pixels.getRawArray())
            img.flipVertically()
            return img
        }
    }

    public prop directions: UInt32 {
        get() {
            m_directions
        }
    }
}
