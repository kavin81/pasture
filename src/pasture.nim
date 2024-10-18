import std/[private/osdirs,oids,asynchttpserver,asyncdispatch,tables,strutils]


proc handleGET(req: Request) {.async.} =
    let path = req.url.path
    if path == "/":
        await req.respond(Http200, "path: /")
    else:
        let hash = path[1..^1]

        try:
            let file = readFile("pasture/" & hash)
            await req.respond(Http200, file)
        except IOError:
            await req.respond(Http404, "File not found")

proc parseMultipartFormData(req: Request): Table[string, string] =
    var formData = initTable[string, string]()
    var contentType, boundary, body: string
    var inHeader = true

    let headers = req.headers["content-type"]
    let strheader = toString(headers)
    let spl = strheader.split(';')
    contentType = spl[0]

    if contentType == "multipart/form-data":
        let data = req.body.splitLines()
        boundary = data[0]

        for line in data[1..^2]:
            # write logic from fresh here
            if line.startsWith(boundary):
                inHeader = true
                continue

            if inHeader:
                if line == "\r\n" or line == "":
                    inHeader = false
                continue

            body.add(line & '\n')


            let linSplit = line.split(';')
            for part in linSplit:
                let content = part.split('=')
                let meta = part.split(':')
                if content.len > 1:
                    formData[content[0]] = content[1]
                if meta.len > 1:
                    formData[meta[0]] = meta[1]

        formData["body"] = body

    return formData


proc handlePOST(req: Request) {.async.} =
    let data = parseMultipartFormData(req)
    if data["body"] == "":
        await req.respond(Http200, "File has no body. Nothing written to pasture")
        return
    let hash = genOid()
    writeFile("pasture/" & $hash, data["body"].strip())
    req.respond(Http200, "File saved. Hash:" & $hash & $'\n')



proc reqHandler(req: Request) {.async.} =
    case req.reqMethod:
    of HttpMethod.HttpGet:
        echo req.url.path
        await handleGET(req)
    of HttpPost:
        echo "POST"
        await handlePOST(req)
    else: discard

proc main() {.async.}=
    discard existsOrCreateDir("pasture")
    let server = newAsyncHttpServer()
    await serve(server, Port(8008),reqHandler)

when isMainModule:
    waitFor main()
