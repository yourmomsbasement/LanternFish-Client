' The Jellyfin device profile for this Roku: what it plays directly, and what the server should transcode to.
' Built from what the device and the connected display report, so a 4K HDR Roku Ultra direct-plays HEVC HDR10 while
' a Roku Express gets H.264 SDR.

function JF_DeviceProfile() as Object
    info = CreateObject("roDeviceInfo")
    caps = JF_Capabilities(info)

    videoCodecs = JF_Join(caps.videoCodecs, ",")
    audioCodecs = JF_Join(caps.audioCodecs, ",")
    transcodeAudio = "aac"
    if caps.ac3 then transcodeAudio = "aac,ac3"
    if caps.eac3 then transcodeAudio = transcodeAudio + ",eac3"
    ' HLS output: H.264, plus HEVC when the Roku decodes it so a remux can keep it
    transcodeVideo = "h264"
    if caps.hevc then transcodeVideo = "h264,hevc"

    channels = "2"
    if caps.ac3 or caps.eac3 then channels = "6"

    hevcProfiles = "main"
    if caps.hevcMain10 then hevcProfiles = "main|main 10"

    return {
        Name: "Lanternfish for Roku",
        MaxStreamingBitrate: caps.maxBitrate,
        MaxStaticBitrate: 200000000,
        MusicStreamingTranscodingBitrate: 192000,
        DirectPlayProfiles: [
            { Type: "Video", Container: "mp4,m4v,mov,mkv", VideoCodec: videoCodecs, AudioCodec: audioCodecs },
            { Type: "Audio", Container: "mp3,aac,m4a,flac,alac,wav" }
        ],
        TranscodingProfiles: [
            {
                Type: "Video", Container: "ts", Protocol: "hls", Context: "Streaming",
                VideoCodec: transcodeVideo, AudioCodec: transcodeAudio, MaxAudioChannels: channels,
                MinSegments: 1, BreakOnNonKeyFrames: true
            },
            { Type: "Audio", Container: "mp3", AudioCodec: "mp3", Protocol: "http", Context: "Streaming", MaxAudioChannels: "2" }
        ],
        ContainerProfiles: [],
        CodecProfiles: [
            {
                Type: "Video", Codec: "h264",
                Conditions: [
                    { Condition: "EqualsAny", Property: "VideoProfile", Value: "high|main|baseline|constrained baseline", IsRequired: false },
                    { Condition: "LessThanEqual", Property: "VideoLevel", Value: "51", IsRequired: false },
                    { Condition: "LessThanEqual", Property: "VideoBitDepth", Value: "8", IsRequired: false },
                    { Condition: "EqualsAny", Property: "VideoRangeType", Value: "SDR", IsRequired: false },
                    { Condition: "LessThanEqual", Property: "Width", Value: caps.maxWidth.ToStr(), IsRequired: false }
                ]
            },
            {
                Type: "Video", Codec: "hevc",
                Conditions: [
                    { Condition: "EqualsAny", Property: "VideoProfile", Value: hevcProfiles, IsRequired: false },
                    { Condition: "EqualsAny", Property: "VideoRangeType", Value: JF_Join(caps.videoRanges, "|"), IsRequired: false },
                    { Condition: "LessThanEqual", Property: "Width", Value: caps.maxWidth.ToStr(), IsRequired: false }
                ]
            }
        ],
        SubtitleProfiles: [
            { Format: "srt", Method: "External" },
            { Format: "subrip", Method: "External" },
            { Format: "vtt", Method: "External" },
            { Format: "webvtt", Method: "External" },
            { Format: "ass", Method: "Encode" },
            { Format: "ssa", Method: "Encode" },
            { Format: "pgssub", Method: "Encode" },
            { Format: "dvdsub", Method: "Encode" },
            { Format: "dvbsub", Method: "Encode" }
        ],
        ResponseProfiles: []
    }
end function

function JF_Capabilities(info as Object) as Object
    caps = {
        videoCodecs: ["h264"],
        audioCodecs: ["aac", "mp3"],
        hevc: JF_CanDecodeVideo(info, { Codec: "hevc", Profile: "main" }),
        hevcMain10: JF_CanDecodeVideo(info, { Codec: "hevc", Profile: "main 10" }),
        ac3: JF_CanDecodeAudio(info, "ac3"),
        eac3: JF_CanDecodeAudio(info, "eac3"),
        videoRanges: ["SDR"],
        maxWidth: 1920,
        maxBitrate: 40000000
    }
    if caps.hevc then caps.videoCodecs.Push("hevc")
    if JF_CanDecodeVideo(info, { Codec: "vp9" }) then caps.videoCodecs.Push("vp9")
    if JF_CanDecodeVideo(info, { Codec: "av1" }) then caps.videoCodecs.Push("av1")
    for each codec in ["ac3", "eac3", "flac", "alac", "opus", "pcm"]
        if JF_CanDecodeAudio(info, codec) then caps.audioCodecs.Push(codec)
    end for

    ' What the connected TV can show, not just what the Roku decodes
    display = info.GetDisplayProperties()
    if display <> invalid
        if JF_IsTrue(display.Hdr10) then caps.videoRanges.Append(["HDR10", "HDR10Plus", "DOVIWithHDR10"])
        if JF_IsTrue(display.HLG) then caps.videoRanges.Append(["HLG", "DOVIWithHLG"])
        if JF_IsTrue(display.DolbyVision) then caps.videoRanges.Append(["DOVI", "DOVIWithSDR"])
    end if

    mode = info.GetVideoMode()
    if mode <> invalid and Instr(1, mode, "2160") > 0
        caps.maxWidth = 3840
        caps.maxBitrate = 120000000
    end if
    return caps
end function

function JF_CanDecodeVideo(info as Object, query as Object) as Boolean
    result = info.CanDecodeVideo(query)
    return result <> invalid and JF_IsTrue(result.Result)
end function

function JF_CanDecodeAudio(info as Object, codec as String) as Boolean
    result = info.CanDecodeAudio({ Codec: codec })
    return result <> invalid and JF_IsTrue(result.Result)
end function

' Seconds (Float) -> ticks, as a LongInteger so FormatJson writes a plain integer
function JF_SecondsToTicks(seconds as Dynamic) as LongInteger
    if seconds = invalid or seconds < 0 then return 0&
    milliseconds& = Int(seconds * 1000)
    return milliseconds& * 10000&
end function
