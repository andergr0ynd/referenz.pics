-- referenz.pics: вход в аккаунт и F8 на сайт.
-- Скопировать в moonloader/referenz.pics.lua и нажать Ctrl+R.
-- /referenz — окно. /referenz update или /refupdate — проверка обновления.
-- Форумы — WebView2 (AZChrome).

script_name('referenz.pics')
script_author('referenz.pics')
script_version('2.77')

local ffi = require 'ffi'
local inicfg = require 'inicfg'

local encoding_ok, encoding = pcall(require, 'encoding')
if encoding_ok then
  encoding.default = 'CP1251'
end

function ru(text)
  if encoding_ok then
    return encoding.UTF8:decode(text)
  end
  return text
end

local SITE = 'https://referenz.pics'

local cfg = inicfg.load({
  referenz = {
    username = '',
    password = '',
    token = '',
    host = 'referenz',
    imgbb = '',
    cefW = 720,
    cefH = 420,
    cefX = -1,
    cefY = -1,
    autoUpdate = '1',
  }
}, 'referenz')

if (cfg.referenz.host or '') == 'pixsafe' then
  cfg.referenz.host = 'referenz'
end

pcall(function()
  local old = inicfg.load({ lumina = {} }, 'lumina')
  if old.lumina and (not cfg.referenz.token or cfg.referenz.token == '') then
    cfg.referenz.username = old.lumina.username or ''
    cfg.referenz.password = old.lumina.password or ''
    cfg.referenz.token = old.lumina.token or ''
  end
end)

local busy = false
local hubWant = false
local dropHub = false
local f8Wait = false
local f8Clock = 0
local needClose = false
local authPending = { mode = '', user = '' }
local DLG_USER = 87531
local DLG_PASS = 87532
local WM_KEYDOWN = 0x0100
local VK_F8 = 0x77

local mim_ok, imgui = pcall(require, 'mimgui')
local old_imgui_ok, old_imgui = pcall(require, 'imgui')
if not mim_ok then imgui = nil end
if not old_imgui_ok then old_imgui = nil end

local ui = { ready = false, showClassic = false, msg = '' }

if imgui then
  ui.show = imgui.new.bool(false)
  ui.user = imgui.new.char[64]()
  ui.pass = imgui.new.char[64]()
  ui.imgbb = imgui.new.char[80]()
  ui.albumTitle = imgui.new.char[81]()
  ui.albumDesc = imgui.new.char[281]()
  ui.hub = imgui.new.bool(false)
  ui.cefBar = imgui.new.bool(true)
  ui.rail = imgui.new.bool(true)
  ui.side = imgui.new.bool(true)
  ui.autoUpdate = imgui.new.bool(tostring(cfg.referenz.autoUpdate or '1') ~= '0')
  pcall(ffi.fill, ui.imgbb, 80)
  ui.ready = 'mimgui'
elseif old_imgui then
  ui.userC = old_imgui.ImBuffer(64)
  ui.passC = old_imgui.ImBuffer(64)
  ui.imgbbC = old_imgui.ImBuffer(80)
  ui.ready = 'imgui'
end

ffi.cdef[[
typedef unsigned long DWORD;
typedef unsigned int UINT;
typedef unsigned long ULONG;

typedef struct _FILETIME { DWORD dwLowDateTime; DWORD dwHighDateTime; } FILETIME;
typedef struct _WIN32_FIND_DATAA {
  DWORD dwFileAttributes;
  FILETIME ftCreationTime;
  FILETIME ftLastWriteTime;
  FILETIME ftLastAccessTime;
  DWORD nFileSizeHigh;
  DWORD nFileSizeLow;
  DWORD dwReserved0;
  DWORD dwReserved1;
  char cFileName[260];
  char cAlternateFileName[14];
} WIN32_FIND_DATAA;
void* FindFirstFileA(const char*, WIN32_FIND_DATAA*);
int FindNextFileA(void*, WIN32_FIND_DATAA*);
int FindClose(void*);

typedef struct tagRECT { long left; long top; long right; long bottom; } RECT;
typedef struct tagBITMAPINFOHEADER {
  DWORD biSize;
  long biWidth;
  long biHeight;
  unsigned short biPlanes;
  unsigned short biBitCount;
  DWORD biCompression;
  DWORD biSizeImage;
  long biXPelsPerMeter;
  long biYPelsPerMeter;
  DWORD biClrUsed;
  DWORD biClrImportant;
} BITMAPINFOHEADER;
void* GetForegroundWindow();
void* FindWindowA(const char*, const char*);
void* GetDC(void*);
int ReleaseDC(void*, void*);
int GetClientRect(void*, RECT*);
void* CreateCompatibleDC(void*);
void* CreateCompatibleBitmap(void*, int, int);
void* SelectObject(void*, void*);
int BitBlt(void*, int, int, int, int, void*, int, int, unsigned long);
int DeleteObject(void*);
int DeleteDC(void*);
int GetDIBits(void*, void*, unsigned int, unsigned int, void*, BITMAPINFOHEADER*, unsigned int);
void GetSystemTimeAsFileTime(FILETIME*);

typedef struct {
  unsigned int GdiplusVersion;
  void* DebugEventCallback;
  int SuppressBackgroundThread;
  int SuppressExternalCodecs;
} GdiplusStartupInput;
int GdiplusStartup(void** token, const GdiplusStartupInput* input, void* output);
int GdipCreateBitmapFromHBITMAP(void* hbm, void* hpal, void** bitmap);
int GdipSaveImageToFile(void* image, const unsigned short* filename, const unsigned char* clsidEncoder, void* encoderParams);
int GdipDisposeImage(void* image);

typedef void* HINTERNET;
HINTERNET InternetOpenA(const char*, DWORD, const char*, const char*, DWORD);
HINTERNET InternetConnectA(HINTERNET, const char*, unsigned short, const char*, const char*, DWORD, DWORD, DWORD);
HINTERNET HttpOpenRequestA(HINTERNET, const char*, const char*, const char*, const char*, const char**, DWORD, DWORD);
int HttpSendRequestA(HINTERNET, const char*, DWORD, void*, DWORD);
int InternetReadFile(HINTERNET, void*, DWORD, DWORD*);
int InternetCloseHandle(HINTERNET);
int InternetSetOptionA(HINTERNET, DWORD, void*, DWORD);
DWORD GetLastError();

HINTERNET WinHttpOpen(const unsigned short*, DWORD, const unsigned short*, const unsigned short*, DWORD);
HINTERNET WinHttpConnect(HINTERNET, const unsigned short*, unsigned short, DWORD);
HINTERNET WinHttpOpenRequest(HINTERNET, const unsigned short*, const unsigned short*, const unsigned short*, const unsigned short*, const unsigned short**, DWORD);
int WinHttpSetOption(HINTERNET, DWORD, void*, DWORD);
int WinHttpSendRequest(HINTERNET, const unsigned short*, DWORD, void*, DWORD, DWORD, DWORD);
int WinHttpReceiveResponse(HINTERNET, void*);
int WinHttpReadData(HINTERNET, void*, DWORD, DWORD*);
int WinHttpCloseHandle(HINTERNET);
]]

local wininet = ffi.load('wininet')
local kernel32 = ffi.load('kernel32')
local user32 = ffi.load('user32')
local gdi32 = ffi.load('gdi32')
local gdiplus = nil
local gdipToken = ffi.new('void*[1]')
local jpegClsid = ffi.new('unsigned char[16]', {
  0x01, 0xF4, 0x7C, 0x55, 0x04, 0x1A, 0xD3, 0x11,
  0x9A, 0x73, 0x00, 0x00, 0xF8, 0x1E, 0xF3, 0x2E
})
pcall(function()
  gdiplus = ffi.load('gdiplus')
  local input = ffi.new('GdiplusStartupInput')
  input.GdiplusVersion = 1
  if gdiplus.GdiplusStartup(gdipToken, input, nil) ~= 0 then
    gdiplus = nil
  end
end)
local winhttp = nil
pcall(function()
  winhttp = ffi.load('winhttp')
end)

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function b64encode(data)
  local out = {}
  for i = 1, #data, 3 do
    local a, b, c = data:byte(i, i + 2)
    b = b or 0
    c = c or 0
    local n = a * 65536 + b * 256 + c
    local c1 = math.floor(n / 262144) % 64 + 1
    local c2 = math.floor(n / 4096) % 64 + 1
    local c3 = math.floor(n / 64) % 64 + 1
    local c4 = n % 64 + 1
    if not data:byte(i + 1) then
      out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. '=='
    elseif not data:byte(i + 2) then
      out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. '='
    else
      out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. B64:sub(c4, c4)
    end
  end
  return table.concat(out)
end

function chat(text)
  pcall(function()
    if sampAddChatMessage then
      sampAddChatMessage(ru('[referenz.pics] ' .. tostring(text or '')), 0xFFE4C15A)
    end
  end)
end

function wide(str)
  str = tostring(str or '')
  local n = #str
  local buf = ffi.new('unsigned short[?]', n + 1)
  for i = 1, n do
    buf[i - 1] = str:byte(i)
  end
  buf[n] = 0
  return buf
end

function lastErr()
  return tonumber(kernel32.GetLastError()) or 0
end

function parseUrl(url)
  local scheme, rest = url:match('^(https?)://(.+)$')
  if not scheme then return nil end
  local hostport, path = rest:match('^([^/]+)(/.*)$')
  if not hostport then
    hostport, path = rest, '/'
  end
  local host, port = hostport:match('^([^:]+):(%d+)$')
  if not host then
    host, port = hostport, (scheme == 'https' and 443 or 80)
  end
  return scheme, host, tonumber(port), path
end

function httpWinHttp(method, scheme, host, port, path, headers, body)
  if not winhttp then return nil, 'winhttp' end
  body = body or ''
  headers = headers or ''
  local hOpen = winhttp.WinHttpOpen(wide('referenz.pics'), 0, nil, nil, 0)
  if hOpen == nil then return nil, 'open ' .. lastErr() end
  local proto = ffi.new('DWORD[1]', 0x00000080 + 0x00000200 + 0x00000800)
  winhttp.WinHttpSetOption(hOpen, 84, proto, 4)
  local timeout = ffi.new('DWORD[1]', 20000)
  winhttp.WinHttpSetOption(hOpen, 3, timeout, 4)
  winhttp.WinHttpSetOption(hOpen, 5, timeout, 4)
  winhttp.WinHttpSetOption(hOpen, 6, timeout, 4)
  local hConn = winhttp.WinHttpConnect(hOpen, wide(host), port, 0)
  if hConn == nil then
    winhttp.WinHttpCloseHandle(hOpen)
    return nil, 'connect ' .. lastErr()
  end
  local reqFlags = 0
  if scheme == 'https' then reqFlags = 0x00800000 end
  local hReq = winhttp.WinHttpOpenRequest(hConn, wide(method), wide(path), nil, nil, nil, reqFlags)
  if hReq == nil then
    winhttp.WinHttpCloseHandle(hConn)
    winhttp.WinHttpCloseHandle(hOpen)
    return nil, 'request ' .. lastErr()
  end
  if scheme == 'https' then
    local sec = ffi.new('DWORD[1]', 0x00000100 + 0x00000200 + 0x00001000 + 0x00002000)
    winhttp.WinHttpSetOption(hReq, 31, sec, 4)
  end
  local blen = #body
  local payload = nil
  if blen > 0 then
    payload = ffi.new('char[?]', blen)
    ffi.copy(payload, body)
  end
  local hdr = nil
  local hdrLen = 0
  if headers ~= '' then
    hdr = wide(headers .. '\r\n')
    hdrLen = -1
  end
  local ok = winhttp.WinHttpSendRequest(hReq, hdr, hdrLen, payload, blen, blen, 0)
  if ok == 0 then
    local err = lastErr()
    winhttp.WinHttpCloseHandle(hReq)
    winhttp.WinHttpCloseHandle(hConn)
    winhttp.WinHttpCloseHandle(hOpen)
    return nil, 'send ' .. tostring(err)
  end
  ok = winhttp.WinHttpReceiveResponse(hReq, nil)
  if ok == 0 then
    local err = lastErr()
    winhttp.WinHttpCloseHandle(hReq)
    winhttp.WinHttpCloseHandle(hConn)
    winhttp.WinHttpCloseHandle(hOpen)
    return nil, 'recv ' .. tostring(err)
  end
  local chunks = {}
  local buf = ffi.new('char[8192]')
  local read = ffi.new('DWORD[1]')
  local pulls = 0
  while winhttp.WinHttpReadData(hReq, buf, 8191, read) ~= 0 and read[0] > 0 do
    chunks[#chunks + 1] = ffi.string(buf, read[0])
    pulls = pulls + 1
    if pulls % 4 == 0 and coroutine.running() then
      wait(0)
    end
  end
  winhttp.WinHttpCloseHandle(hReq)
  winhttp.WinHttpCloseHandle(hConn)
  winhttp.WinHttpCloseHandle(hOpen)
  return table.concat(chunks)
end

function httpWininet(method, scheme, host, port, path, headers, body)
  body = body or ''
  headers = headers or ''
  local flags = 0x80000000 + 0x04000000 + 0x00400000
  if scheme == 'https' then flags = flags + 0x00800000 end
  local hOpen = wininet.InternetOpenA('Mozilla/5.0', 1, nil, nil, 0)
  if hOpen == nil then return nil, 'InternetOpen ' .. lastErr() end
  local timeout = ffi.new('DWORD[1]', 20000)
  wininet.InternetSetOptionA(hOpen, 2, timeout, 4)
  wininet.InternetSetOptionA(hOpen, 5, timeout, 4)
  wininet.InternetSetOptionA(hOpen, 6, timeout, 4)
  local hConn = wininet.InternetConnectA(hOpen, host, port, nil, nil, 3, 0, 0)
  if hConn == nil then
    wininet.InternetCloseHandle(hOpen)
    return nil, 'InternetConnect ' .. lastErr()
  end
  local hReq = wininet.HttpOpenRequestA(hConn, method, path, 'HTTP/1.1', nil, nil, flags, 0)
  if hReq == nil then
    wininet.InternetCloseHandle(hConn)
    wininet.InternetCloseHandle(hOpen)
    return nil, 'HttpOpenRequest ' .. lastErr()
  end
  if scheme == 'https' then
    local sec = ffi.new('DWORD[1]', 0x00000100 + 0x00000200 + 0x00001000 + 0x00002000)
    wininet.InternetSetOptionA(hReq, 31, sec, 4)
  end
  local blen = #body
  local payload = nil
  if blen > 0 then
    payload = ffi.new('char[?]', blen)
    ffi.copy(payload, body)
  end
  local hdr = headers ~= '' and (headers .. '\r\n') or ''
  local ok = wininet.HttpSendRequestA(hReq, hdr, #hdr, payload, blen)
  local chunks = {}
  if ok ~= 0 then
    local buf = ffi.new('char[4096]')
    local read = ffi.new('DWORD[1]')
    while wininet.InternetReadFile(hReq, buf, 4095, read) ~= 0 and read[0] > 0 do
      chunks[#chunks + 1] = ffi.string(buf, read[0])
    end
  end
  local err = lastErr()
  wininet.InternetCloseHandle(hReq)
  wininet.InternetCloseHandle(hConn)
  wininet.InternetCloseHandle(hOpen)
  if ok == 0 then return nil, 'HttpSendRequest ' .. tostring(err) end
  return table.concat(chunks)
end

function httpPost(url, headers, body)
  local scheme, host, port, path = parseUrl(url)
  if not host then return nil, 'bad url' end
  local resp, err = httpWinHttp('POST', scheme, host, port, path, headers, body)
  if resp and resp ~= '' then return resp end
  return httpWininet('POST', scheme, host, port, path, headers, body)
end

function httpGet(url, headers)
  local scheme, host, port, path = parseUrl(url)
  if not host then return nil, 'bad url' end
  if winhttp then
    return httpWinHttp('GET', scheme, host, port, path, headers, '')
  end
  return httpWininet('GET', scheme, host, port, path, headers, '')
end

function jsonEscape(s)
  s = tostring(s or '')
  s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n')
  return s
end

function setBuf(buf, str, cap)
  ffi.fill(buf, cap)
  str = tostring(str or '')
  if #str > cap - 1 then str = str:sub(1, cap - 1) end
  ffi.copy(buf, str)
end

function saveCfg()
  pcall(inicfg.save, cfg, 'referenz')
end

function loggedIn()
  return cfg.referenz.token and cfg.referenz.token ~= ''
end

function useImgbb()
  return (cfg.referenz.host or '') == 'imgbb'
end

function imgbbKey()
  return tostring(cfg.referenz.imgbb or ''):gsub('%s+', '')
end

function remoteName()
  if useImgbb() then return 'ImgBB' end
  return 'сайт'
end

function syncSettings()
  if not loggedIn() then return end
  local host = useImgbb() and 'imgbb' or 'referenz'
  local imgbb = imgbbKey()
  if host == 'imgbb' and imgbb == '' then return end
  lua_thread.create(function()
    httpPost(
      SITE .. '/api/settings',
      'Content-Type: application/json\r\nAuthorization: Bearer ' .. tostring(cfg.referenz.token),
      '{"uploadHost":"' .. host .. '","imgbbKey":"' .. jsonEscape(imgbb) .. '"}'
    )
  end)
end

function setHost(name)
  if name == 'imgbb' then
    cfg.referenz.host = 'imgbb'
  else
    cfg.referenz.host = 'referenz'
  end
  saveCfg()
  syncSettings()
  if ui.hub and ui.hub[0] then loadHub() end
end

function grabImgbb()
  pcall(function()
    if ui.ready == 'mimgui' and ui.imgbb then
      cfg.referenz.imgbb = ffi.string(ui.imgbb):gsub('%s+', '')
    elseif ui.ready == 'imgui' and ui.imgbbC then
      cfg.referenz.imgbb = tostring(ui.imgbbC.v or ''):gsub('%s+', '')
    end
  end)
  saveCfg()
  return imgbbKey()
end

function fillAuthFields()
  if ui.ready == 'mimgui' then
    setBuf(ui.user, cfg.referenz.username, 64)
    setBuf(ui.pass, cfg.referenz.password, 64)
    setBuf(ui.imgbb, cfg.referenz.imgbb, 80)
  elseif ui.ready == 'imgui' then
    ui.userC.v = cfg.referenz.username or ''
    ui.passC.v = cfg.referenz.password or ''
    ui.imgbbC.v = cfg.referenz.imgbb or ''
  end
end

function readAuthFields()
  if ui.ready == 'mimgui' then
    return ffi.string(ui.user), ffi.string(ui.pass)
  end
  if ui.ready == 'imgui' then
    return ui.userC.v, ui.passC.v
  end
  return '', ''
end

local mouseHold = false
local setUiMouse
local loginJob = nil
local wantCefClose = false
local texFlag = ffi.new('int[1]')
local texLen = ffi.new('int[1]')
local texBuf = ffi.new('uint8_t[?]', 4 * 1024 * 1024)

function closeWindow()
  grabImgbb()
  syncSettings()
  if ui.ready == 'mimgui' then
    ui.show[0] = false
    mouseHold = false
  else
    ui.showClassic = false
  end
end

function windowOpen()
  if ui.ready == 'mimgui' and ui.show then
    return ui.show[0] and true or false
  end
  return ui.showClassic and true or false
end

function finishAuth(resp, kind, username, password, quiet)
  if not resp or resp == '' then
    ui.msg = 'Нет связи с сайтом'
    return false
  end
  local errorText = resp:match('"error"%s*:%s*"(.-)"')
  if errorText then
    ui.msg = errorText
    return false
  end
  local tok = resp:match('"apiToken"%s*:%s*"([%w]+)"')
  if not tok then
    ui.msg = 'Не удалось войти'
    return false
  end
  cfg.referenz.username = username
  cfg.referenz.password = password
  cfg.referenz.token = tok
  local host = resp:match('"uploadHost"%s*:%s*"(%w+)"')
  local key = resp:match('"imgbbKey"%s*:%s*"([^"]*)"')
  if host == 'imgbb' or host == 'referenz' then
    cfg.referenz.host = host
  end
  if key and key ~= '' then
    cfg.referenz.imgbb = key
  end
  saveCfg()
  fillAuthFields()
  ui.msg = kind == 'register' and 'Аккаунт создан' or ('Вход: ' .. username)
  closeWindow()
  if not quiet then
    chat(kind == 'register' and 'Аккаунт создан' or ('Вход: ' .. username))
    hubWant = true
  end
  return true
end

function doAuth(kind, username, password, quiet)
  username = tostring(username or ''):gsub('^%s+', ''):gsub('%s+$', '')
  password = tostring(password or '')
  if username == '' or password == '' then
    ui.msg = 'Введите логин и пароль'
    return false
  end
  local payload = '{"username":"' .. jsonEscape(username) .. '","password":"' .. jsonEscape(password) .. '"}'
  local path = kind == 'register' and '/api/register' or '/api/login'
  local resp, err = httpPost(SITE .. path, 'Content-Type: application/json', payload)
  if not resp then
    ui.msg = 'Нет связи с сайтом' .. (err and (' (' .. err .. ')') or '')
    return false
  end
  return finishAuth(resp, kind, username, password, quiet)
end

function startAuth(kind)
  local user, pass = readAuthFields()
  lua_thread.create(function()
    doAuth(kind, user, pass)
  end)
end

function openLoginWindow()
  ui.msg = ''
  fillAuthFields()
  if ui.ready == 'mimgui' then
    ui.show[0] = true
    mouseHold = true
    return
  end
  if ui.ready == 'imgui' then
    ui.showClassic = true
    return
  end
  authPending.mode = 'login'
  authPending.user = ''
  sampShowDialog(DLG_USER, 1, ru('referenz.pics'), ru('Введите логин'), ru('Далее'), ru('Отмена'))
end

function doLogout()
  cfg.referenz.username = ''
  cfg.referenz.password = ''
  cfg.referenz.token = ''
  saveCfg()
  fillAuthFields()
  ui.msg = ''
  hub.loginGen = (hub.loginGen or 0) + 1
  loginJob = nil
  dropHub = true
  hub.openLogin = true
  chat('Вы вышли')
end

local WIN_W = 400
local WIN_H = 560

local PAL = {
  gold = { 0.894, 0.757, 0.353, 1 },
  gold2 = { 0.953, 0.851, 0.541, 1 },
  ink = { 0.102, 0.078, 0.024, 1 },
  text = { 0.957, 0.937, 0.894, 1 },
  muted = { 0.608, 0.576, 0.525, 1 },
  bg = { 0.047, 0.047, 0.055, 0.97 },
  frame = { 0.070, 0.070, 0.082, 1 },
  hover = { 0.141, 0.129, 0.094, 1 },
  border = { 0.894, 0.757, 0.353, 0.28 },
  btn = { 0.894, 0.757, 0.353, 1 },
  btnH = { 0.957, 0.851, 0.541, 1 },
  btnA = { 0.72, 0.58, 0.20, 1 },
  ghost = { 0.141, 0.129, 0.094, 1 },
  err = { 1, 0.545, 0.545, 1 },
  ok = { 0.55, 0.86, 0.55, 1 },
}

function v4(lib, c)
  return lib.ImVec4(c[1], c[2], c[3], c[4] or 1)
end

function pushHardStyle(lib)
  local nCol, nVar = 0, 0
  local function col(name, c)
    if lib.Col and lib.Col[name] ~= nil then
      if pcall(lib.PushStyleColor, lib.Col[name], v4(lib, c)) then
        nCol = nCol + 1
      end
    end
  end
  local function var(name, a, b)
    if lib.StyleVar and lib.StyleVar[name] ~= nil then
      local ok
      if b ~= nil then
        ok = pcall(lib.PushStyleVar, lib.StyleVar[name], lib.ImVec2(a, b))
      else
        ok = pcall(lib.PushStyleVar, lib.StyleVar[name], a)
      end
      if ok then nVar = nVar + 1 end
    end
  end
  col('Text', PAL.text)
  col('TextDisabled', PAL.muted)
  col('WindowBg', PAL.bg)
  col('ChildBg', PAL.frame)
  col('PopupBg', PAL.bg)
  col('Border', PAL.border)
  col('FrameBg', PAL.frame)
  col('FrameBgHovered', PAL.hover)
  col('FrameBgActive', PAL.hover)
  col('TitleBg', PAL.bg)
  col('TitleBgActive', PAL.bg)
  col('Button', PAL.ghost)
  col('ButtonHovered', PAL.hover)
  col('ButtonActive', PAL.btnA)
  col('Header', PAL.ghost)
  col('Separator', PAL.border)
  col('CheckMark', PAL.gold)
  col('SliderGrab', PAL.gold)
  col('ScrollbarGrab', PAL.gold)
  var('WindowRounding', 12)
  var('FrameRounding', 8)
  var('ChildRounding', 8)
  var('GrabRounding', 8)
  var('WindowBorderSize', 1)
  var('FrameBorderSize', 1)
  var('WindowPadding', 0, 0)
  var('FramePadding', 12, 8)
  var('ItemSpacing', 10, 8)
  return nCol, nVar
end

function popHardStyle(lib, nCol, nVar)
  if nCol > 0 then pcall(lib.PopStyleColor, nCol) end
  if nVar > 0 then pcall(lib.PopStyleVar, nVar) end
end

function windowFlags(lib)
  local f = 1 + 2 + 32
  if not mouseHold then f = f + 512 end
  pcall(function()
    local W = lib.WindowFlags
    if W then
      f = (W.NoTitleBar or 1) + (W.NoResize or 2) + (W.NoCollapse or 32)
      if not mouseHold then f = f + (W.NoMouseInputs or 512) end
    end
  end)
  return f
end

function goldBtn(lib, label, w, h)
  local n = 0
  if lib.PushStyleColor and lib.Col then
    if pcall(lib.PushStyleColor, lib.Col.Button, v4(lib, PAL.btn)) then n = n + 1 end
    if pcall(lib.PushStyleColor, lib.Col.ButtonHovered, v4(lib, PAL.btnH)) then n = n + 1 end
    if pcall(lib.PushStyleColor, lib.Col.ButtonActive, v4(lib, PAL.btnA)) then n = n + 1 end
    if pcall(lib.PushStyleColor, lib.Col.Text, v4(lib, PAL.ink)) then n = n + 1 end
  end
  local clicked = lib.Button(label, lib.ImVec2(w, h))
  if n > 0 then pcall(lib.PopStyleColor, n) end
  return clicked
end

function drawHostSwitch(lib, w, h)
  local cur = cfg.referenz.host or 'referenz'
  local function one(id, label)
    if cur == id then
      goldBtn(lib, label, w, h)
    elseif lib.Button(label, lib.ImVec2(w, h)) then
      grabImgbb()
      setHost(id)
      if id == 'imgbb' and imgbbKey() == '' then
        ui.msg = 'Вставьте ключ ImgBB'
        openLoginWindow()
      end
    end
  end
  one('referenz', 'referenz')
  if lib.SameLine then lib.SameLine(0, 6) end
  one('imgbb', 'ImgBB')
end

local LOGO_URL = 'https://raw.githubusercontent.com/andergr0ynd/referenz.pics/refs/heads/main/images/logo-256.png'
local LOGO_URL_CDN = 'https://cdn.jsdelivr.net/gh/andergr0ynd/referenz.pics@main/images/logo-256.png'
local LOGO_PATH = getWorkingDirectory() .. '\\images\\referenz-logo.png'
local FORUM_URL = 'https://www.blast.hk/threads/257840/#post-1696751'
local logo = {
  tex = nil,
  kick = false,
  fetched = false,
  busy = false,
  job = nil,
}

function ensureDir(path)
  if type(doesDirectoryExist) == 'function' and doesDirectoryExist(path) then return end
  if type(createDirectory) == 'function' then
    pcall(createDirectory, path)
    return
  end
  pcall(function() kernel32.CreateDirectoryA(path, nil) end)
end

function logoIsPng(path)
  local f = io.open(path, 'rb')
  if not f then return false end
  local head = f:read(8)
  local size = f:seek('end') or 0
  f:close()
  if not head or #head < 4 then return false end
  return head:byte(1) == 137 and head:byte(2) == 80 and head:byte(3) == 78 and head:byte(4) == 71 and size > 1500
end

function loadLogoTex()
  if logo.tex or not imgui then return end
  if not logoIsPng(LOGO_PATH) then return end
  local ok, tex = pcall(imgui.CreateTextureFromFile, LOGO_PATH)
  if ok and tex then logo.tex = tex end
end

function applyLogoPart()
  local part = LOGO_PATH .. '.part'
  if not logoIsPng(part) then
    pcall(os.remove, part)
    logo.busy = false
    return
  end
  pcall(os.remove, LOGO_PATH)
  if not os.rename(part, LOGO_PATH) then
    pcall(function()
      local src = io.open(part, 'rb')
      local dst = io.open(LOGO_PATH, 'wb')
      if src and dst then dst:write(src:read('*a')) end
      if src then src:close() end
      if dst then dst:close() end
      os.remove(part)
    end)
  else
    pcall(os.remove, part)
  end
  logo.busy = false
  logo.tex = nil
  loadLogoTex()
end

function fetchLogo()
  if logo.busy or logo.fetched then return end
  logo.fetched = true
  logo.busy = true
  ensureDir(getWorkingDirectory() .. '\\images')
  local part = LOGO_PATH .. '.part'
  pcall(os.remove, part)
  if type(downloadUrlToFile) == 'function' then
    local ml = require('moonloader')
    local ds = ml and ml.download_status
    logo.job = { done = false, ok = false, t0 = os.clock(), url = 1 }
    local job = logo.job
    local urls = { LOGO_URL, LOGO_URL_CDN }
    pcall(downloadUrlToFile, urls[1] .. '?t=' .. tostring(os.time()), part, function(_, status)
      if not ds or not job then return end
      if status == ds.STATUS_ENDDOWNLOADDATA or status == ds.STATUSEX_ENDDOWNLOAD then
        job.done = true
        job.ok = true
      end
    end)
    return
  end
  lua_thread.create(function()
    local body = updateFetch and updateFetch({ LOGO_URL, LOGO_URL_CDN }, 1500) or nil
    if type(body) ~= 'string' or #body < 1500
      or body:byte(1) ~= 137 or body:byte(2) ~= 80 or body:byte(3) ~= 78 or body:byte(4) ~= 71 then
      logo.busy = false
      return
    end
    pcall(function()
      local f = io.open(part, 'wb')
      if f then
        f:write(body)
        f:close()
      end
    end)
    applyLogoPart()
  end)
end

function pumpLogo()
  local job = logo.job
  if not job then return end
  if job.done then
    logo.job = nil
    if job.ok then
      applyLogoPart()
    else
      pcall(os.remove, LOGO_PATH .. '.part')
      logo.busy = false
    end
    return
  end
  if os.clock() - (job.t0 or 0) > 25 then
    logo.job = nil
    pcall(os.remove, LOGO_PATH .. '.part')
    logo.busy = false
  end
end

function kickLogo()
  if logo.kick then return end
  logo.kick = true
  loadLogoTex()
  if not logo.tex then fetchLogo() end
end

function openForumTopic()
  pcall(ffi.cdef, [[
    void* __stdcall ShellExecuteA(void* hwnd, const char* op, const char* file,
      const char* params, const char* dir, int show);
  ]])
  local opened = false
  pcall(function()
    ffi.load('Shell32').ShellExecuteA(nil, 'open', FORUM_URL, nil, nil, 1)
    opened = true
  end)
  if not opened then
    os.execute('cmd /c start "" "' .. FORUM_URL .. '"')
  end
end

function drawBrandHeader(lib, width, withVersion)
  kickLogo()
  width = width or 120
  local h = 0
  if logo.tex and lib.Image then
    local logoW = math.min(108, width)
    local logoH = math.floor(logoW * 9 / 16)
    if logoH < 48 then logoH = 48 end
    lib.Image(logo.tex, lib.ImVec2(logoW, logoH))
    h = logoH + 6
    if lib.Dummy then lib.Dummy(lib.ImVec2(0, 4)) end
  end
  if lib.TextColored then
    lib.TextColored(v4(lib, PAL.text), 'referenz')
    lib.SameLine(0, 0)
    lib.TextColored(v4(lib, PAL.gold), '.pics')
  else
    lib.Text('referenz.pics')
  end
  if withVersion then
    lib.SameLine()
    lib.TextDisabled('v' .. tostring(thisScript().version or ''))
  end
  return h + 22
end

function drawUpdatePanel(lib, compact)
  if lib.Dummy then lib.Dummy(lib.ImVec2(0, compact and 6 or 10)) end
  lib.TextDisabled(compact and 'обновление' or 'автообновление GitHub')
  if ui.autoUpdate and lib.Checkbox and not compact then
    if lib.Checkbox('Проверять через 45 сек после спавна', ui.autoUpdate) then
      cfg.referenz.autoUpdate = ui.autoUpdate[0] and '1' or '0'
      saveCfg()
    end
  end
  local label = updateBusy and 'Проверяю…' or (compact and 'Проверить' or 'Проверить сейчас')
  if goldBtn(lib, label, -1, compact and 28 or 32) then
    checkUpdate(true)
  end
  if lib.Dummy then lib.Dummy(lib.ImVec2(0, 4)) end
  if lib.Button(compact and 'blast.hk' or 'Тема на blast.hk', lib.ImVec2(-1, compact and 26 or 28)) then
    openForumTopic()
  end
end

function drawLoginWindow()
  local lib = imgui or old_imgui
  if not lib then return end
  local nCol, nVar = pushHardStyle(lib)
  if lib.SetNextWindowSize then
    lib.SetNextWindowSize(lib.ImVec2(WIN_W, WIN_H), 4)
  end
  pcall(function()
    local sw, sh = getScreenResolution()
    lib.SetNextWindowPos(lib.ImVec2(sw / 2, sh / 2), 2, lib.ImVec2(0.5, 0.5))
  end)
  local visible = true
  if ui.ready == 'mimgui' then
    visible = imgui.Begin('##referenz', ui.show, windowFlags(lib))
  else
    visible = old_imgui.Begin('referenz.pics')
    old_imgui.ShowCursor = true
  end
  if visible then
    pcall(function()
      local dl = lib.GetWindowDrawList()
      local min = lib.GetWindowPos()
      local sz = lib.GetWindowSize()
      local gold = lib.ColorConvertFloat4ToU32(v4(lib, PAL.gold))
      dl:AddRectFilled(min, lib.ImVec2(min.x + 4, min.y + sz.y), gold, 2)
    end)

    if lib.SetCursorPos then lib.SetCursorPos(lib.ImVec2(WIN_W - 50, 12)) end
    if lib.PushStyleColor and lib.Col then
      pcall(lib.PushStyleColor, lib.Col.Button, lib.ImVec4(0.80, 0.22, 0.32, 0.45))
      pcall(lib.PushStyleColor, lib.Col.ButtonHovered, lib.ImVec4(0.90, 0.25, 0.35, 0.75))
    end
    if lib.Button('X', lib.ImVec2(28, 28)) then closeWindow() end
    pcall(lib.PopStyleColor, 2)

    if lib.SetCursorPos then lib.SetCursorPos(lib.ImVec2(22, 16)) end
    local brandH = drawBrandHeader(lib, WIN_W - 56, true)

    if lib.SetCursorPos then lib.SetCursorPos(lib.ImVec2(22, 16 + brandH)) end
    if lib.BeginChild then
      lib.BeginChild('##body', lib.ImVec2(WIN_W - 36, WIN_H - 28 - brandH), false)
    end

    lib.TextDisabled('куда грузить F8')
    drawHostSwitch(lib, 168, 28)
    if useImgbb() then
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 6)) end
      lib.TextDisabled('API-ключ с api.imgbb.com')
      if lib.PushItemWidth then lib.PushItemWidth(-1) end
      if ui.ready == 'mimgui' then
        if lib.InputTextWithHint then
          lib.InputTextWithHint('##imgbb', 'ключ ImgBB', ui.imgbb, 80)
        else
          lib.InputText('ImgBB', ui.imgbb, 80)
        end
      else
        lib.InputText('ImgBB', ui.imgbbC)
      end
      if lib.PopItemWidth then lib.PopItemWidth() end
    end
    if lib.Dummy then lib.Dummy(lib.ImVec2(0, 8)) end

    if loggedIn() then
      lib.TextDisabled('аккаунт')
      if lib.TextColored then
        lib.TextColored(v4(lib, PAL.gold), tostring(cfg.referenz.username))
      else
        lib.Text(tostring(cfg.referenz.username))
      end
      if useImgbb() then
        lib.TextDisabled('F8 отдаёт ссылку ' .. remoteName())
      else
        lib.TextDisabled('F8 снимает кадр и грузит на сайт')
      end
      if ui.msg ~= '' then
        lib.TextColored(v4(lib, PAL.ok), ui.msg)
      end
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 10)) end
      if goldBtn(lib, 'Закрыть', -1, 36) then closeWindow() end
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 6)) end
      if lib.Button('Выйти из аккаунта', lib.ImVec2(-1, 32)) then
        doLogout()
      end
    else
      if useImgbb() then
        lib.TextDisabled('аккаунт сайта не обязателен')
      else
        lib.TextDisabled('логин и пароль с сайта')
      end
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 8)) end
      if lib.PushItemWidth then lib.PushItemWidth(-1) end
      local passFlags = lib.InputTextFlags and lib.InputTextFlags.Password or 0
      if ui.ready == 'mimgui' then
        if lib.InputTextWithHint then
          lib.InputTextWithHint('##user', 'логин', ui.user, 64)
          if lib.Dummy then lib.Dummy(lib.ImVec2(0, 4)) end
          lib.InputTextWithHint('##pass', 'пароль', ui.pass, 64, passFlags)
        else
          lib.InputText('Логин', ui.user, 64)
          lib.InputText('Пароль', ui.pass, 64, passFlags)
        end
      else
        lib.InputText('Логин', ui.userC)
        lib.InputText('Пароль', ui.passC, passFlags)
      end
      if lib.PopItemWidth then lib.PopItemWidth() end
      if ui.msg ~= '' then
        if lib.Dummy then lib.Dummy(lib.ImVec2(0, 6)) end
        lib.TextColored(v4(lib, PAL.err), ui.msg)
      end
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 12)) end
      if goldBtn(lib, 'Войти', -1, 36) then
        startAuth('login')
      end
      if lib.Dummy then lib.Dummy(lib.ImVec2(0, 6)) end
      if lib.Button('Регистрация', lib.ImVec2(-1, 32)) then
        startAuth('register')
      end
    end
    drawUpdatePanel(lib)

    if lib.EndChild then lib.EndChild() end
  end
  lib.End()
  popHardStyle(lib, nCol, nVar)
end

local FORUMS = {
  { name = 'Arizona', url = 'https://forum.arizona-rp.com/' },
  { name = 'Blast', url = 'https://www.blast.hk/' },
  { name = 'Rodina', url = 'https://forum.rodina-rp.com/' },
  { name = 'Radmir', url = 'https://forum.radmir.games/' },
}

local CEF_W, CEF_H = 720, 420
local CEF_MIN_W, CEF_MIN_H = 560, 340
local CEF_MAX_W, CEF_MAX_H = 960, 540
local cefOpen = false
local cursorTold = false
local cefView = { x = 40, y = 80, w = CEF_W, h = CEF_H, placed = false }
local barDragX, barDragY
local barSizeX, barSizeY
local sizeHeld = false
local sizeApply = false
local dragHeld = false
local typingOn = false
local barMouse = false
local altWas = false
local cefCommitW, cefCommitH = CEF_W, CEF_H
local hub = {
  tab = 'shots',
  shots = {},
  albums = {},
  tex = {},
  mem = {},
  raw = {},
  loading = false,
  note = '',
  forum = '',
  openAlbum = nil,
  albumShots = {},
  albumMsg = '',
  albumBusy = false,
  moveOpen = false,
  confirmDel = false,
  side = 'shots',
  sideAlbum = nil,
  sideShots = {},
  sideNote = '',
  miss = {},
}

pcall(function()
ffi.cdef[[
typedef struct { long x; long y; } POINT;
int GdipLoadImageFromFile(const unsigned short* filename, void** image);
int GdipGetImageWidth(void* image, unsigned int* width);
int GdipGetImageHeight(void* image, unsigned int* height);
int GdipGetImageThumbnail(void* image, unsigned int thumbWidth, unsigned int thumbHeight, void** thumbImage, void* callback, void* callbackData);
int CreateDirectoryA(const char* path, void* sec);
int IsWindowVisible(void* hwnd);
int GetWindowRect(void* hwnd, RECT* rect);
int ClientToScreen(void* hwnd, POINT* pt);
int ScreenToClient(void* hwnd, POINT* pt);
unsigned long GetWindowThreadProcessId(void* hwnd, unsigned long* pid);
unsigned long GetCurrentProcessId();
void* GetModuleHandleA(const char* name);
int IsWindow(void* h);
short GetAsyncKeyState(int vk);
int ReleaseCapture(void);
int CloseHandle(void* h);
int TerminateProcess(void* h, unsigned int code);
typedef struct { unsigned long cb; char* lpReserved; char* lpDesktop; char* lpTitle; unsigned long dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags; unsigned short wShowWindow, cbReserved2; unsigned char* lpReserved2; void* hStdInput; void* hStdOutput; void* hStdError; } AZ_SI;
typedef struct { void* hProcess; void* hThread; unsigned long dwProcessId; unsigned long dwThreadId; } AZ_PI;
int CreateProcessA(const char* app, char* cmd, void* pa, void* ta, int inherit, unsigned long flags, void* env, const char* cwd, AZ_SI* si, AZ_PI* pi);
]]
end)
pcall(ffi.cdef, 'int ScreenToClient(void* hwnd, POINT* pt);')
pcall(ffi.cdef, 'void* GetParent(void* hwnd);')
pcall(ffi.cdef, 'short __stdcall GetAsyncKeyState(int vKey);')


-- WebView2 helper (AZChrome), embedded.
AZ_BLOBS = {
setup = [=====[

param([string]$Dir)
$ErrorActionPreference = 'Stop'
$st = Join-Path $Dir 'setup_status.txt'
$enc = New-Object System.Text.UTF8Encoding($false)
try {
    [IO.File]::WriteAllText($st, 'working', $enc)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $bin = Join-Path $Dir 'bin'
    New-Item -ItemType Directory -Force -Path (Join-Path $bin 'x64') | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $bin 'x86') | Out-Null
    $pkg = Join-Path $Dir 'webview2.nupkg'
    (New-Object Net.WebClient).DownloadFile('https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2', $pkg)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($pkg)
    try {
        $map = @(
            @('^lib/net4\d*/Microsoft\.Web\.WebView2\.Core\.dll$', 'Microsoft.Web.WebView2.Core.dll'),
            @('^lib/net4\d*/Microsoft\.Web\.WebView2\.WinForms\.dll$', 'Microsoft.Web.WebView2.WinForms.dll'),
            @('^runtimes/win-x64/native/WebView2Loader\.dll$', 'x64\WebView2Loader.dll'),
            @('^runtimes/win-x86/native/WebView2Loader\.dll$', 'x86\WebView2Loader.dll')
        )
        foreach ($m in $map) {
            $e = $zip.Entries | Where-Object { $_.FullName -match $m[0] } | Select-Object -First 1
            if ($null -eq $e) { throw ('entry not found: ' + $m[0]) }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($e, (Join-Path $bin $m[1]), $true)
        }
    } finally { $zip.Dispose() }
    Remove-Item $pkg -Force -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText($st, 'ok', $enc)
} catch {
    $msg = ($_.Exception.Message -replace '[\r\n]+', ' ')
    [IO.File]::WriteAllText($st, ('error ' + $msg), $enc)
}

]=====],
  helper_ps = [=====[

param([string]$Dir, [long]$OwnerHwnd, [int]$GamePid, [string]$Sid, [int]$Gm = 0)
$ErrorActionPreference = 'Stop'
$statePath = Join-Path $Dir ('state_' + $Sid + '.txt')
try {
    $bin = Join-Path $Dir 'bin'
    $arch = if ([Environment]::Is64BitProcess) { 'x64' } else { 'x86' }
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class AzLoad { [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr LoadLibraryW(string p); }'
    $lib = [AzLoad]::LoadLibraryW((Join-Path (Join-Path $bin $arch) 'WebView2Loader.dll'))
    if ($lib -eq [IntPtr]::Zero) { throw 'WebView2Loader.dll was not loaded' }
    $core = Join-Path $bin 'Microsoft.Web.WebView2.Core.dll'
    $wf = Join-Path $bin 'Microsoft.Web.WebView2.WinForms.dll'
    Add-Type -Path $core
    Add-Type -Path $wf
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $src = [IO.File]::ReadAllText((Join-Path $Dir 'helper.cs'), [Text.Encoding]::UTF8)
    Add-Type -ReferencedAssemblies @($core, $wf, 'System.Windows.Forms.dll', 'System.Drawing.dll') -TypeDefinition $src -Language CSharp
    [AzApp]::Run($Dir, [IntPtr]$OwnerHwnd, $GamePid, $Sid, $Gm)
} catch {
    $full = ($_ | Out-String)
    try { Add-Content -Path (Join-Path $Dir 'helper.log') -Value $full } catch { }
    $msg = ($_.Exception.Message -replace '[\r\n]+', ' ')
    [IO.File]::WriteAllText($statePath, ('fatal ' + $msg + "`nready 0`n"), (New-Object Text.UTF8Encoding($false)))
}

]=====],
  helper_cs = [=====[

using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Windows.Forms;
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.WinForms;

public static class AzApp
{
    public static void Run(string dir, IntPtr owner, int gamePid, string sid, int gm)
    {
        try { Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException); } catch (Exception) { }
        try { System.Runtime.GCSettings.LatencyMode = System.Runtime.GCLatencyMode.SustainedLowLatency; } catch (Exception) { }
        AppDomain.CurrentDomain.UnhandledException += delegate(object s0, UnhandledExceptionEventArgs e0)
        {
            try { File.AppendAllText(Path.Combine(dir, "helper.log"), DateTime.Now.ToString() + " FATAL " + e0.ExceptionObject + "\r\n"); }
            catch (Exception) { }
        };
        Application.ThreadException += delegate(object s, System.Threading.ThreadExceptionEventArgs e)
        {
            try { File.AppendAllText(Path.Combine(dir, "helper.log"), DateTime.Now.ToString() + " " + e.Exception.ToString() + "\r\n"); }
            catch (Exception) { }
        };
        Application.EnableVisualStyles();
        AzForm f = new AzForm(dir, owner, gamePid, sid, gm != 0);
        f.Boot();
        Application.Run();
    }
}

public class AzForm : Form
{
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }

    [DllImport("user32.dll")] static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] static extern bool ClientToScreen(IntPtr h, ref POINT p);
    [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll", EntryPoint = "SetWindowLong")] static extern int SetWindowLong32(IntPtr h, int i, int v);
    [DllImport("user32.dll", EntryPoint = "SetWindowLongPtr")] static extern IntPtr SetWindowLongPtr64(IntPtr h, int i, IntPtr v);
    [DllImport("user32.dll")] static extern bool ReleaseCapture();
    [DllImport("user32.dll")] static extern bool SetLayeredWindowAttributes(IntPtr h, uint key, byte alpha, uint flags);

    const string JS_TOGGLE = "(function(){var m=document.querySelectorAll('video,audio'),p=[],i;for(i=0;i<m.length;i++){if(!m[i].paused)p.push(m[i]);}"
        + "if(p.length){for(i=0;i<p.length;i++)p[i].pause();return;}"
        + "var t=null;for(i=0;i<m.length;i++){if(m[i].readyState>0){t=m[i];break;}}if(!t&&m.length)t=m[0];if(t)t.play();})()";
    const string JS_PAUSE = "(function(){var m=document.querySelectorAll('video,audio');for(var i=0;i<m.length;i++)m[i].pause();})()";
    const string JS_PROBE = "(function(){var m=document.querySelectorAll('video,audio');if(!m.length)return '';var p=0,t=0,d=0;"
        + "for(var i=0;i<m.length;i++){if(!m[i].paused){p=1;t=m[i].currentTime;d=isFinite(m[i].duration)?m[i].duration:0;break;}}"
        + "return p+','+t+','+d;})()";
    const string JS_FRAME = "(function(){if(window.__azfr)return 1;if(!window.__azfq){window.__azfq=1;requestAnimationFrame(function(){window.__azfr=1;});}return 0;})()";

    WebView2 wv;
    IntPtr owner;
    int gamePid;
    string dir, cmdPath, statePath;
    FileStream cmdFs;
    MemoryStream acc = new MemoryStream();
    Timer tCmd = new Timer();
    Timer tSlow = new Timer();

    string mode = "hide";
    bool inter = true, locked = false, landscape = false, ready = false, busy = false, mute = false;
    string fKind = "none";
    float fTop, fBottom, fSide, fRadius, fRimW;
    Color fBody = Color.Black, fRim = Color.Gray;
    int resX = 1920, resY = 1080;
    double vol = 60;
    string startUrl = "https://www.google.com";
    string scriptId = null;
    bool volDirty = false, regBusy = false;
    Rectangle webRect = new Rectangle(0, 0, 10, 10);
    int posN = 0, posX = 0, posY = 0;
    long tickN = 0;
    string fatal = null, lastProbe = "", regionKey = "";
    double scX = 1.0, scY = 1.0;
    float fZoom = 1f;
    double zoomNow = 1.0;

    bool gm, loaded, frameSeen;
    int btnMask = 0;
    string heldBtn = "none";
    string recover = null;

    public AzForm(string dir, IntPtr owner, int gamePid, string sid, bool gm)
    {
        this.dir = dir; this.owner = owner; this.gamePid = gamePid; this.gm = gm;
        cmdPath = Path.Combine(dir, "cmd_" + sid + ".txt");
        statePath = Path.Combine(dir, "state_" + sid + ".txt");
        AutoScaleMode = AutoScaleMode.None;
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        BackColor = Color.FromArgb(18, 18, 20);
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.UserPaint, true);
        Bounds = new Rectangle(-32000, -32000, 200, 200);
        wv = new WebView2();
        Controls.Add(wv);
        tCmd.Interval = 20;
        tCmd.Tick += delegate { PollCmd(); };
        tSlow.Interval = 500;
        tSlow.Tick += delegate { Slow(); };
    }

    protected override bool ShowWithoutActivation { get { return true; } }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cp = base.CreateParams;
            cp.ExStyle |= 0x80; // TOOLWINDOW
            if (gm) cp.ExStyle |= 0x08000000 | 0x80000 | 0x20; // NOACTIVATE | LAYERED | TRANSPARENT
            return cp;
        }
    }

    protected override void OnHandleCreated(EventArgs e)
    {
        base.OnHandleCreated(e);
        if (gm)
        {
            try { SetLayeredWindowAttributes(Handle, 0, 255, 2); } catch (Exception) { }
        }
    }

    static void SetOwner(IntPtr h, IntPtr o)
    {
        if (IntPtr.Size == 8) SetWindowLongPtr64(h, -8, o);
        else SetWindowLong32(h, -8, o.ToInt32());
    }

    public void Boot()
    {
        IntPtr h = this.Handle;
        SetOwner(h, owner);
        wv.CoreWebView2InitializationCompleted += OnInit;
        tCmd.Start();
        tSlow.Start();
        WriteState();
        IntPtr wh = wv.Handle;
        BootWeb();
    }

    async void BootWeb()
    {
        try
        {
            CoreWebView2EnvironmentOptions opt = new CoreWebView2EnvironmentOptions();
            opt.AdditionalBrowserArguments = gm
                ? "--autoplay-policy=no-user-gesture-required --disable-features=CalculateNativeWinOcclusion --disable-backgrounding-occluded-windows --disable-renderer-backgrounding --disable-background-timer-throttling"
                : "--autoplay-policy=no-user-gesture-required";
            CoreWebView2Environment env = await CoreWebView2Environment.CreateAsync(null, Path.Combine(dir, "profile"), opt);
            await wv.EnsureCoreWebView2Async(env);
        }
        catch (Exception ex)
        {
            fatal = "WebView2: " + ex.Message;
            WriteState();
        }
    }

    void Log(string t)
    {
        try { File.AppendAllText(Path.Combine(dir, "helper.log"), DateTime.Now.ToString("HH:mm:ss.fff") + " " + t + "\r\n"); }
        catch (Exception) { }
    }

    static string Num(double d) { return d.ToString("0.###", CultureInfo.InvariantCulture); }
    static double D(string s)
    {
        double d;
        if (!double.TryParse(s, NumberStyles.Float, CultureInfo.InvariantCulture, out d)) d = 0;
        return d;
    }
    static Color Col(string s)
    {
        uint v;
        if (!uint.TryParse(s, NumberStyles.Integer, CultureInfo.InvariantCulture, out v)) v = 0xFF000000;
        return Color.FromArgb(unchecked((int)v));
    }
    static string Clean(string s)
    {
        if (s == null) return "";
        return s.Replace("\r", " ").Replace("\n", " ");
    }

    static double VolFactor(double v) { return Math.Max(0.0, Math.Min(4.0, v / 100.0)); }

    string InjectJs()
    {
        return "(function(){if(window.__az)return;"
             + "var S=window.__az={v:" + Num(VolFactor(vol)) + ",ctx:null};"
             + "var AC=window.AudioContext||window.webkitAudioContext;"
             + "function safe(v){var s=v.currentSrc||v.src||'';if(!s||s.indexOf('blob:')===0||s.indexOf('data:')===0)return true;"
             + "try{if(new URL(s,location.href).origin===location.origin)return true;}catch(e){return false;}"
             + "return v.crossOrigin!==null;}"
             + "function graph(v){try{"
             + "if(!AC)return null;"
             + "if(!S.ctx)S.ctx=new AC();"
             + "if(S.ctx.state!=='running'){S.ctx.resume();return null;}"
             + "var g=v.__azg;"
             + "if(!g){var src=S.ctx.createMediaElementSource(v),gain=S.ctx.createGain(),comp=S.ctx.createDynamicsCompressor();"
             + "comp.threshold.value=-8;comp.knee.value=10;comp.ratio.value=10;comp.attack.value=0.004;comp.release.value=0.15;"
             + "src.connect(gain);gain.connect(S.ctx.destination);g=v.__azg={gain:gain,comp:comp,amp:false};}"
             + "return g;}catch(e){v.__azf=1;return null;}}"
             + "function route(g,on){if(g.amp===on)return;g.gain.disconnect();g.comp.disconnect();"
             + "if(on){g.gain.connect(g.comp);g.comp.connect(S.ctx.destination);}else{g.gain.connect(S.ctx.destination);}g.amp=on;}"
             + "function apply(v){var t=S.v,base=Math.min(t,1),amp=Math.max(t,1);"
             + "if(Math.abs(v.volume-base)>0.004)v.volume=base;"
             + "if(v.__azf)return;"
             + "if(v.__azg||(amp>1.001&&safe(v))){var g=graph(v);if(g){g.gain.gain.value=amp;route(g,amp>1.001);}}}"
             + "function setv(x){S.v=x;try{for(var i=0;i<window.frames.length;i++){window.frames[i].postMessage({__az:x},'*');}}catch(e){}}"
             + "window.__azSet=setv;"
             + "window.addEventListener('message',function(e){var d=e.data;if(!d||typeof d!=='object')return;"
             + "if(typeof d.__az==='number'&&e.source===window.parent)setv(d.__az);"
             + "else if(d.__azq===1&&e.source)e.source.postMessage({__az:S.v},'*');});"
             + "if(window.parent!==window){try{window.parent.postMessage({__azq:1},'*');}catch(e){}}"
             + "setInterval(function(){var m=document.querySelectorAll('video,audio');for(var i=0;i<m.length;i++)apply(m[i]);},400);"
             + "})();";
    }

    void OnInit(object sender, CoreWebView2InitializationCompletedEventArgs e)
    {
        if (!e.IsSuccess)
        {
            fatal = "WebView2: " + (e.InitializationException != null ? e.InitializationException.Message : "init failed");
            WriteState();
            return;
        }
        CoreWebView2 c = wv.CoreWebView2;
        try
        {
            c.Settings.IsStatusBarEnabled = false;
            c.Settings.AreDevToolsEnabled = false;
            c.Settings.IsZoomControlEnabled = false;
            if (gm) c.Settings.AreDefaultContextMenusEnabled = false;
            c.IsMuted = mute;
            c.NewWindowRequested += (s2, a) => { a.Handled = true; try { c.Navigate(a.Uri); } catch (Exception) { } };
            c.ContentLoading += (s2, a) => { MarkLoaded(); };
            c.DOMContentLoaded += (s2, a) => { MarkLoaded(); PushVol(); };
            c.NavigationCompleted += (s2, a) => { MarkLoaded(); PushVol(); ApplyZoom(); };
            RegScript();
            try
            {
                c.Settings.AreDefaultScriptDialogsEnabled = false;
                c.ScriptDialogOpening += (s2, a) =>
                {
                    try
                    {
                        Log("dialog " + a.Kind + ": " + Clean(a.Message));
                        if (a.Kind == CoreWebView2ScriptDialogKind.Alert || a.Kind == CoreWebView2ScriptDialogKind.Beforeunload) a.Accept();
                    }
                    catch (Exception) { }
                };
                c.ProcessFailed += (s2, a) =>
                {
                    try
                    {
                        Log("process failed " + a.ProcessFailedKind);
                        if (a.ProcessFailedKind == CoreWebView2ProcessFailedKind.BrowserProcessExited)
                        {
                            recover = "процесс браузера завершился";
                            WriteState();
                        }
                        else if (a.ProcessFailedKind == CoreWebView2ProcessFailedKind.RenderProcessExited
                            || a.ProcessFailedKind == CoreWebView2ProcessFailedKind.RenderProcessUnresponsive)
                        {
                            c.Reload();
                        }
                    }
                    catch (Exception) { }
                };
            }
            catch (Exception) { }
            ready = true;
            ApplyZoom();
            c.Navigate(startUrl);
        }
        catch (Exception ex)
        {
            fatal = "WebView2 setup: " + ex.Message;
        }
        WriteState();
    }

    void MarkLoaded()
    {
        if (loaded) return;
        loaded = true;
        WriteState();
    }

    void Js(string code)
    {
        CoreWebView2 c = wv.CoreWebView2;
        if (c == null) return;
        try { c.ExecuteScriptAsync(code); } catch (Exception) { }
    }

    void PushVol()
    {
        Js("if(window.__azSet){window.__azSet(" + Num(VolFactor(vol)) + ");}");
    }

    async void RegScript()
    {
        CoreWebView2 c = wv.CoreWebView2;
        if (c == null || regBusy) return;
        regBusy = true;
        try
        {
            string old = scriptId;
            scriptId = await c.AddScriptToExecuteOnDocumentCreatedAsync(InjectJs());
            if (old != null) c.RemoveScriptToExecuteOnDocumentCreated(old);
        }
        catch (Exception) { }
        finally { regBusy = false; }
    }

    void PollCmd()
    {
        try
        {
            if (cmdFs == null)
            {
                if (!File.Exists(cmdPath)) return;
                cmdFs = new FileStream(cmdPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            }
            byte[] buf = new byte[4096];
            int n;
            while ((n = cmdFs.Read(buf, 0, buf.Length)) > 0)
            {
                for (int i = 0; i < n; i++)
                {
                    if (buf[i] == 10)
                    {
                        string line = Encoding.UTF8.GetString(acc.ToArray()).Trim('\r');
                        acc.SetLength(0);
                        try { Exec(line); } catch (Exception) { }
                    }
                    else acc.WriteByte(buf[i]);
                }
            }
        }
        catch (Exception) { }
    }

    void Exec(string line)
    {
        if (line.Length == 0) return;
        int sp = line.IndexOf(' ');
        string cmd = sp < 0 ? line : line.Substring(0, sp);
        string arg = sp < 0 ? "" : line.Substring(sp + 1);
        string[] a = arg.Split(' ');
        CoreWebView2 c = wv.CoreWebView2;
        switch (cmd)
        {
            case "view": SetView(a); break;
            case "frame":
                fKind = a[0];
                fTop = (float)D(a[1]); fBottom = (float)D(a[2]); fSide = (float)D(a[3]); fRadius = (float)D(a[4]);
                fBody = Col(a[5]); fRim = Col(a[6]); fRimW = (float)D(a[7]);
                landscape = a[8] == "1";
                fZoom = a.Length > 9 ? (float)D(a[9]) : 1f;
                if (mode == "float") { regionKey = ""; Relayout(); }
                break;
            case "inter": inter = a[0] == "1"; UpdateInteractive(); break;
            case "blur": if (Form.ActiveForm == this) SetForegroundWindow(owner); break;
            case "vol": vol = D(a[0]); PushVol(); volDirty = true; break;
            case "mute": mute = a[0] == "1"; if (c != null) c.IsMuted = mute; break;
            case "lock": locked = a[0] == "1"; break;
            case "start": startUrl = arg; break;
            case "nav": if (c != null) { try { c.Navigate(arg); } catch (Exception) { } } break;
            case "back": if (c != null && c.CanGoBack) c.GoBack(); break;
            case "fwd": if (c != null && c.CanGoForward) c.GoForward(); break;
            case "reload": if (c != null) c.Reload(); break;
            case "home": if (c != null) c.Navigate(startUrl); break;
            case "play": Js(JS_TOGGLE); break;
            case "pause": Js(JS_PAUSE); break;
            case "clear": if (c != null) { try { c.CookieManager.DeleteAllCookies(); c.Reload(); } catch (Exception) { } } break;
            case "mm": Mouse("mouseMoved", PX(a[0]), PY(a[1]), heldBtn, 0, 0, 0, 0); break;
            case "ml": Mouse("mouseMoved", -1, -1, "none", 0, 0, 0, 0); break;
            case "md":
                {
                    btnMask |= BtnBit(a[2]);
                    heldBtn = BtnName(a[2]);
                    Mouse("mousePressed", PX(a[0]), PY(a[1]), BtnName(a[2]), I(a[4]), I(a[3]), 0, 0);
                }
                break;
            case "mu":
                {
                    btnMask &= ~BtnBit(a[2]);
                    Mouse("mouseReleased", PX(a[0]), PY(a[1]), BtnName(a[2]), I(a[4]), I(a[3]), 0, 0);
                    if (btnMask == 0) heldBtn = "none";
                }
                break;
            case "mw": Mouse("mouseWheel", PX(a[0]), PY(a[1]), "none", 0, I(a[3]), 0, I(a[2])); break;
            case "kd": DispatchKeyDown(I(a[0]), I(a[1]), I(a[2]), a[3], a[4]); break;
            case "ku": DispatchKeyUp(I(a[0]), I(a[1]), a[2]); break;
            case "kc": KeyChar(I(a[0]), I(a[1]), I(a[2])); break;
            case "quit": Application.Exit(); break;
        }
    }

    static int I(string s) { return (int)D(s); }
    static string BtnName(string b) { return b == "l" ? "left" : (b == "r" ? "right" : "middle"); }
    static int BtnBit(string b) { return b == "l" ? 1 : (b == "r" ? 2 : 4); }

    void Cdp(string method, string json)
    {
        CoreWebView2 c = wv.CoreWebView2;
        if (c == null) return;
        try { c.CallDevToolsProtocolMethodAsync(method, json); } catch (Exception) { }
    }

    void Mouse(string type, double x, double y, string btn, int clicks, int mods, int dx, int dy)
    {
        string j = "{\"type\":\"" + type + "\",\"x\":" + Num(x) + ",\"y\":" + Num(y) + ",\"button\":\"" + btn + "\",\"buttons\":" + btnMask
            + ",\"modifiers\":" + mods + ",\"clickCount\":" + clicks;
        if (type == "mouseWheel") j += ",\"deltaX\":" + dx + ",\"deltaY\":" + dy;
        Cdp("Input.dispatchMouseEvent", j + "}");
    }

    double PX(string f) { return D(f) / 10000.0 * Math.Max(1, wv.Width) / zoomNow; }
    double PY(string f) { return D(f) / 10000.0 * Math.Max(1, wv.Height) / zoomNow; }

    static string KeyCode(string name)
    {
        if (name.Length == 1 && char.IsLetter(name[0])) return "Key" + name.ToUpperInvariant();
        return name;
    }

    void DispatchKeyDown(int vk, int mods, int rep, string name, string cmd)
    {
        bool enter = name == "Enter";
        string j = "{\"type\":\"" + (enter ? "keyDown" : "rawKeyDown") + "\",\"modifiers\":" + mods
            + ",\"windowsVirtualKeyCode\":" + vk + ",\"nativeVirtualKeyCode\":" + vk
            + ",\"key\":\"" + name + "\",\"code\":\"" + KeyCode(name) + "\",\"autoRepeat\":" + (rep != 0 ? "true" : "false");
        if (enter) j += ",\"text\":\"\\r\",\"unmodifiedText\":\"\\r\"";
        if (cmd != "-") j += ",\"commands\":[\"" + cmd + "\"]";
        Cdp("Input.dispatchKeyEvent", j + "}");
    }

    void DispatchKeyUp(int vk, int mods, string name)
    {
        string j = "{\"type\":\"keyUp\",\"modifiers\":" + mods + ",\"windowsVirtualKeyCode\":" + vk + ",\"nativeVirtualKeyCode\":" + vk;
        if (name != "-") j += ",\"key\":\"" + name + "\",\"code\":\"" + KeyCode(name) + "\"";
        Cdp("Input.dispatchKeyEvent", j + "}");
    }

    void KeyChar(int cp, int vk, int mods)
    {
        string t = "\\u" + (cp & 0xFFFF).ToString("x4");
        Cdp("Input.dispatchKeyEvent", "{\"type\":\"keyDown\",\"modifiers\":" + mods + ",\"windowsVirtualKeyCode\":" + vk
            + ",\"nativeVirtualKeyCode\":" + vk + ",\"key\":\"" + t + "\",\"text\":\"" + t + "\",\"unmodifiedText\":\"" + t + "\"}");
    }

    void SetView(string[] a)
    {
        string m = a[0];
        if (m == "hide")
        {
            mode = "hide";
            if (Visible) Hide();
            return;
        }
        double x = D(a[1]), y = D(a[2]), w = D(a[3]), h = D(a[4]);
        resX = (int)D(a[5]); resY = (int)D(a[6]);
        if (mode != m)
        {
            ReleaseCapture();
            mode = m;
            regionKey = "";
            if (Enabled) { Enabled = false; Enabled = true; }
        }
        ApplyBounds(x, y, w, h);
        if (!Visible) Show();
        UpdateInteractive();
    }

    void ApplyBounds(double x, double y, double w, double h)
    {
        if (!IsWindow(owner)) return;
        RECT cr;
        POINT o = new POINT();
        GetClientRect(owner, out cr);
        ClientToScreen(owner, ref o);
        double cw = cr.R - cr.L, ch = cr.B - cr.T;
        scX = (resX > 0 && cw > 0) ? cw / resX : 1.0;
        scY = (resY > 0 && ch > 0) ? ch / resY : 1.0;
        Rectangle r = new Rectangle(
            o.X + (int)Math.Round(x * scX), o.Y + (int)Math.Round(y * scY),
            Math.Max(40, (int)Math.Round(w * scX)), Math.Max(40, (int)Math.Round(h * scY)));
        if (Bounds != r) Bounds = r;
        Relayout();
    }

    void UpdateInteractive()
    {
        if (gm) return;
        bool want = (mode == "main") || (mode == "float" && inter);
        if (Enabled != want)
        {
            if (!want && Form.ActiveForm == this) SetForegroundWindow(owner);
            Enabled = want;
        }
    }

    void Relayout()
    {
        int W = ClientSize.Width, H = ClientSize.Height;
        if (mode == "float" && fKind != "none")
        {
            int t = (int)Math.Round(fTop * scX), b = (int)Math.Round(fBottom * scX), s = (int)Math.Round(fSide * scX);
            if (!landscape) webRect = new Rectangle(s, t, Math.Max(10, W - 2 * s), Math.Max(10, H - t - b));
            else webRect = new Rectangle(t, s, Math.Max(10, W - t - b), Math.Max(10, H - 2 * s));
        }
        else webRect = new Rectangle(0, 0, W, H);
        if (wv.Bounds != webRect) wv.Bounds = webRect;
        string key = mode + "|" + W + "x" + H + "|" + fRadius + "|" + fKind + "|" + landscape;
        if (key != regionKey)
        {
            regionKey = key;
            if (mode == "float" && fKind != "none" && fRadius > 0.5f)
            {
                using (GraphicsPath gp = RoundRect(new RectangleF(0, 0, W, H), (float)(fRadius * scX)))
                {
                    Region = new Region(gp);
                }
            }
            else Region = null;
            Invalidate();
        }
        ApplyZoom();
    }

    void ApplyZoom()
    {
        if (wv.CoreWebView2 == null) return;
        double z = (mode == "float") ? fZoom * scX : 1.0;
        z = Math.Max(0.25, Math.Min(5.0, z));
        try { if (Math.Abs(wv.ZoomFactor - z) > 0.002) wv.ZoomFactor = z; zoomNow = z; }
        catch (Exception) { }
    }

    static GraphicsPath RoundRect(RectangleF r, float rad)
    {
        GraphicsPath p = new GraphicsPath();
        float d = Math.Min(rad * 2f, Math.Min(r.Width, r.Height));
        if (d < 1f) { p.AddRectangle(r); return p; }
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    static void FillRound(Graphics g, Color c, RectangleF r, float rad)
    {
        using (GraphicsPath p = RoundRect(r, rad))
        using (SolidBrush br = new SolidBrush(c)) g.FillPath(br, p);
    }

    protected override void OnActivated(EventArgs e)
    {
        base.OnActivated(e);
        if (wv.CoreWebView2 != null && Enabled) wv.Focus();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        Graphics g = e.Graphics;
        int W = ClientSize.Width, H = ClientSize.Height;
        using (SolidBrush bg = new SolidBrush(BackColor)) g.FillRectangle(bg, 0, 0, W, H);
        if (mode != "float" || fKind == "none") return;
        g.SmoothingMode = SmoothingMode.AntiAlias;
        float k = (float)scX;
        using (GraphicsPath gp = RoundRect(new RectangleF(0.5f, 0.5f, W - 1, H - 1), fRadius * k))
        {
            using (SolidBrush body = new SolidBrush(fBody)) g.FillPath(body, gp);
            using (Pen rim = new Pen(fRim, Math.Max(1f, fRimW * k))) g.DrawPath(rim, gp);
        }
        GraphicsState st = g.Save();
        float pw = W, ph = H;
        if (landscape)
        {
            g.TranslateTransform(0, H);
            g.RotateTransform(-90f);
            pw = H; ph = W;
        }
        DrawDeco(g, pw, ph, fTop * k, fBottom * k, k);
        g.Restore(st);
    }

    void DrawDeco(Graphics g, float pw, float ph, float t, float bt, float k)
    {
        Color dark = Color.FromArgb(255, 5, 5, 6);
        Color light = Color.FromArgb(170, 205, 205, 210);
        if (fKind == "pill")
        {
            float w = pw * 0.30f, h = t * 0.46f;
            FillRound(g, dark, new RectangleF((pw - w) / 2f, (t - h) / 2f, w, h), h / 2f);
            float cd = h * 0.5f;
            using (SolidBrush lb = new SolidBrush(Color.FromArgb(255, 22, 26, 44)))
                g.FillEllipse(lb, (pw + w) / 2f - h * 0.9f, (t - cd) / 2f, cd, cd);
            float bw = pw * 0.34f, bh = Math.Max(2f, bt * 0.14f);
            FillRound(g, light, new RectangleF((pw - bw) / 2f, ph - bt / 2f - bh / 2f, bw, bh), bh / 2f);
        }
        else if (fKind == "punch")
        {
            float d = t * 0.46f;
            using (SolidBrush db = new SolidBrush(dark)) g.FillEllipse(db, (pw - d) / 2f, (t - d) / 2f, d, d);
            using (Pen rp = new Pen(Color.FromArgb(255, 34, 38, 58), Math.Max(1f, k)))
                g.DrawEllipse(rp, (pw - d) / 2f + d * 0.28f, (t - d) / 2f + d * 0.28f, d * 0.44f, d * 0.44f);
        }
        else if (fKind == "classic")
        {
            float sw = pw * 0.28f, sh = Math.Max(3f, t * 0.09f);
            FillRound(g, dark, new RectangleF((pw - sw) / 2f, t * 0.5f - sh / 2f, sw, sh), sh / 2f);
            float cd = Math.Max(4f, t * 0.12f);
            using (SolidBrush cb = new SolidBrush(Color.FromArgb(255, 18, 22, 36)))
                g.FillEllipse(cb, (pw - sw) / 2f - cd * 2.2f, t * 0.5f - cd / 2f, cd, cd);
            float hd = bt * 0.52f;
            using (Pen hp = new Pen(Color.FromArgb(255, 96, 98, 104), Math.Max(1.5f, 2f * k)))
                g.DrawEllipse(hp, (pw - hd) / 2f, ph - bt / 2f - hd / 2f, hd, hd);
        }
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == 0x21 && gm) { m.Result = (IntPtr)3; return; }
        if (m.Msg == 0x84 && mode == "float" && !locked && inter)
        {
            long lp = m.LParam.ToInt64();
            int px = (short)(lp & 0xFFFF);
            int py = (short)((lp >> 16) & 0xFFFF);
            Point cp = PointToClient(new Point(px, py));
            if (!webRect.Contains(cp)) { m.Result = (IntPtr)2; return; }
        }
        base.WndProc(ref m);
        if (m.Msg == 0x232) ReportPos();
    }

    void ReportPos()
    {
        if (mode != "float" || !IsWindow(owner)) return;
        POINT o = new POINT();
        ClientToScreen(owner, ref o);
        posX = (int)Math.Round((Left - o.X) / (scX > 0 ? scX : 1.0));
        posY = (int)Math.Round((Top - o.Y) / (scY > 0 ? scY : 1.0));
        posN++;
        WriteState();
    }

    async void Slow()
    {
        tickN++;
        try
        {
            if (!IsWindow(owner)) { Application.Exit(); return; }
            if (gamePid > 0)
            {
                try { if (Process.GetProcessById(gamePid).HasExited) { Application.Exit(); return; } }
                catch (Exception) { Application.Exit(); return; }
            }
            if (volDirty && !regBusy) { volDirty = false; RegScript(); }
            CoreWebView2 c = wv.CoreWebView2;
            if (c != null && !busy)
            {
                busy = true;
                try
                {
                    lastProbe = (await c.ExecuteScriptAsync(JS_PROBE) ?? "").Trim('"');
                    if (loaded && !frameSeen && Visible && mode != "hide")
                    {
                        string fr = (await c.ExecuteScriptAsync(JS_FRAME) ?? "").Trim('"');
                        if (fr == "1") frameSeen = true;
                    }
                }
                catch (Exception) { }
                finally { busy = false; }
            }
            WriteState();
        }
        catch (Exception) { }
    }

    void WriteState()
    {
        try
        {
            CoreWebView2 c = wv.CoreWebView2;
            StringBuilder sb = new StringBuilder();
            sb.Append("tick ").Append(tickN).Append('\n');
            if (fatal != null) sb.Append("fatal ").Append(Clean(fatal)).Append('\n');
            if (recover != null) sb.Append("recover ").Append(Clean(recover)).Append('\n');
            sb.Append("ready ").Append(ready ? 1 : 0).Append('\n');
            sb.Append("loaded ").Append(loaded ? 1 : 0).Append('\n');
            sb.Append("frame ").Append(frameSeen ? 1 : 0).Append('\n');
            if (c != null)
            {
                sb.Append("url ").Append(Clean(c.Source)).Append('\n');
                sb.Append("title ").Append(Clean(c.DocumentTitle)).Append('\n');
            }
            sb.Append("vid ").Append(lastProbe).Append('\n');
            sb.Append("pos ").Append(posX).Append(' ').Append(posY).Append(' ').Append(posN).Append('\n');
            File.WriteAllText(statePath, sb.ToString(), new UTF8Encoding(false));
        }
        catch (Exception) { }
    }
}

]=====],
}

local AZ_DIR = getWorkingDirectory() .. '\\config\\referenz_browser'
local AZ_BTN = { [0] = 'left', [1] = 'right', [2] = 'middle' }
local az = {
  status = 'idle',
  err = '',
  sid = '',
  pid = nil,
  cmd = nil,
  state = nil,
  sent = {},
  title = '',
  tick = nil,
  tick_t = 0,
  started_at = 0,
  setup_at = 0,
  gm = true,
  hproc = nil,
  old_proc = nil,
  old_kill = 0,
  hold = 0,
  pending = false,
  tries = 1,
  loaded = false,
  frame = false,
  shown = false,
  gave_up = false,
  wait = 0,
  want_url = '',
  ready_nav = false,
  cap = {},
  mx = -1,
  my = -1,
  was_hov = false,
  clk = nil,
  web_hit = false,
  kb = false,
}
local azPid = tonumber(kernel32.GetCurrentProcessId())
local azBlobs = nil

function azLoadBlobs()
  if azBlobs then return azBlobs end
  if type(AZ_BLOBS) == 'table' and AZ_BLOBS.setup and AZ_BLOBS.helper_ps and AZ_BLOBS.helper_cs then
    azBlobs = AZ_BLOBS
    return azBlobs
  end
  az.err = 'внутри скрипта нет данных браузера'
  return nil
end

function azWrite(path, s)
  local f = io.open(path, 'wb')
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

function azRead(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local ok, s = pcall(function() return f:read('*a') end)
  f:close()
  if not ok or type(s) ~= 'string' or s == '' then return nil end
  return s
end

function azParseState(s)
  local st = {}
  s = tostring(s or '')
  local pos = 1
  while true do
    local a, b = s:find('[^\r\n]+', pos)
    if not a then break end
    local line = s:sub(a, b)
    pos = b + 1
    local k, v = line:match('^(%S+) ?(.*)$')
    if k then st[k] = v end
  end
  return st
end

function azAppend(path, s)
  local f = io.open(path, 'ab')
  if not f then return false end
  f:write(s, '\n')
  f:close()
  return true
end

function azLog(text)
  pcall(function()
    kernel32.CreateDirectoryA(AZ_DIR, nil)
    local f = io.open(AZ_DIR .. '\\helper.log', 'ab')
    if f then
      f:write(os.date('%H:%M:%S') .. ' [lua] ' .. tostring(text) .. '\r\n')
      f:close()
    end
  end)
end

function azSend(line)
  if az.cmd then azAppend(az.cmd, line) end
end

function azSendK(key, line)
  if az.sent[key] ~= line then
    az.sent[key] = line
    azSend(line)
  end
end

function azPageReady()
  return az.status == 'ready' and (az.loaded or az.gave_up)
end

function azGameHwnd()
  local function mine(h)
    if h == nil or user32.IsWindow(h) == 0 then return false end
    local b = ffi.new('unsigned long[1]')
    user32.GetWindowThreadProcessId(h, ffi.cast('void*', b))
    return tonumber(b[0]) == azPid
  end
  local h = user32.FindWindowA('Grand theft auto San Andreas', nil)
  if mine(h) then return h end
  local ok, v = pcall(readMemory, 0x00C8CF88, 4, false)
  if ok and v and v ~= 0 then
    h = ffi.cast('void*', v)
    if mine(h) then return h end
  end
  return nil
end

function azSpawn(cmdline, keep)
  local si = ffi.new('AZ_SI')
  si.cb = ffi.sizeof('AZ_SI')
  si.dwFlags = 1
  si.wShowWindow = 0
  local pi = ffi.new('AZ_PI')
  local buf = ffi.new('char[?]', #cmdline + 1)
  ffi.copy(buf, cmdline)
  local ok = kernel32.CreateProcessA(nil, buf, nil, nil, 0, 0x08000000, nil, nil, ffi.cast('void*', si), ffi.cast('void*', pi)) ~= 0
  if not ok then return nil end
  local pid = tonumber(pi.dwProcessId)
  kernel32.CloseHandle(pi.hThread)
  if keep then return pid, pi.hProcess end
  kernel32.CloseHandle(pi.hProcess)
  return pid
end

function azCloseProc(h, kill)
  if h == nil then return end
  pcall(function()
    if kill then kernel32.TerminateProcess(h, 0) end
    kernel32.CloseHandle(h)
  end)
end

function azKillHelper()
  azCloseProc(az.hproc, true)
  az.hproc = nil
end

function azPsPath()
  local root = os.getenv('SystemRoot') or 'C:\\Windows'
  local sn = root .. '\\Sysnative\\WindowsPowerShell\\v1.0\\powershell.exe'
  if doesFileExist(sn) then return sn end
  return root .. '\\System32\\WindowsPowerShell\\v1.0\\powershell.exe'
end

function azFilesOk()
  local b = AZ_DIR .. '\\bin\\'
  return doesFileExist(b .. 'Microsoft.Web.WebView2.Core.dll')
    and doesFileExist(b .. 'Microsoft.Web.WebView2.WinForms.dll')
    and doesFileExist(b .. 'x64\\WebView2Loader.dll')
    and doesFileExist(b .. 'x86\\WebView2Loader.dll')
end

function azCleanupOld()
  pcall(function()
    for _, mask in ipairs({ 'cmd_*.txt', 'state_*.txt' }) do
      local h, f = findFirstFile(AZ_DIR .. '\\' .. mask)
      local names = {}
      while f do
        names[#names + 1] = f
        f = findNextFile(h)
      end
      if h then findClose(h) end
      for _, n in ipairs(names) do os.remove(AZ_DIR .. '\\' .. n) end
    end
  end)
end

function azFail(msg)
  azLog('ошибка: ' .. tostring(msg))
  azKillHelper()
  az.status = 'fatal'
  az.err = msg
  az.shown = false
end

function azIsFullscreen()
  local ok, res = pcall(function()
    local pdev = readMemory(0xC97C28, 4, false)
    if not pdev or pdev == 0 then return nil end
    local dev = ffi.cast('void**', pdev)
    if dev[0] == nil then return nil end
    local vtbl = ffi.cast('void**', dev[0])
    local get_sc = ffi.cast('int(__stdcall*)(void*, unsigned int, void**)', vtbl[14])
    local out = ffi.new('void*[1]')
    if get_sc(dev, 0, out) ~= 0 or out[0] == nil then return nil end
    local sc = out[0]
    local scvt = ffi.cast('void**', ffi.cast('void**', sc)[0])
    local pp = ffi.new('unsigned int[16]')
    local r = ffi.cast('int(__stdcall*)(void*, void*)', scvt[9])(sc, pp)
    ffi.cast('unsigned long(__stdcall*)(void*)', scvt[2])(sc)
    if r ~= 0 then return nil end
    return pp[8] == 0
  end)
  if ok then return res end
  return nil
end

function azStartSetup()
  local blobs = azLoadBlobs()
  if not blobs then return azFail(az.err ~= '' and az.err or 'данные браузера повреждены') end
  kernel32.CreateDirectoryA(AZ_DIR, nil)
  az.status = 'setup'
  az.err = ''
  az.setup_at = os.clock()
  azWrite(AZ_DIR .. '\\setup.ps1', blobs.setup)
  os.remove(AZ_DIR .. '\\setup_status.txt')
  local cmd = string.format('"%s" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%s\\setup.ps1" "%s"', azPsPath(), AZ_DIR, AZ_DIR)
  if not azSpawn(cmd) then azFail('не удалось запустить PowerShell') end
end

function azStartHelper()
  local blobs = azLoadBlobs()
  if not blobs then return azFail(az.err ~= '' and az.err or 'данные браузера повреждены') end
  local hwnd = azGameHwnd()
  if not hwnd then return azFail('не найдено окно игры') end
  kernel32.CreateDirectoryA(AZ_DIR, nil)
  azKillHelper()
  azCleanupOld()
  local fs = azIsFullscreen()
  az.gm = (fs ~= false)
  az.loaded, az.frame, az.shown, az.wait = false, false, false, 0
  az.ready_nav = false
  az.sid = tostring(os.time() % 100000) .. tostring(math.random(100, 999))
  az.cmd = AZ_DIR .. '\\cmd_' .. az.sid .. '.txt'
  az.state = AZ_DIR .. '\\state_' .. az.sid .. '.txt'
  az.sent, az.tick, az.title = {}, nil, ''
  azWrite(az.cmd, '')
  azLog('запуск WebView2: ' .. (az.gm and 'полноэкранный' or 'оконный'))
  azWrite(AZ_DIR .. '\\helper.ps1', blobs.helper_ps)
  azWrite(AZ_DIR .. '\\helper.cs', blobs.helper_cs)
  local cmd = string.format('"%s" -NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -File "%s\\helper.ps1" "%s" %.0f %d %s %d',
    azPsPath(), AZ_DIR, AZ_DIR, tonumber(ffi.cast('intptr_t', hwnd)), azPid, az.sid, az.gm and 1 or 0)
  az.pid, az.hproc = azSpawn(cmd, true)
  if not az.pid then return azFail('не удалось запустить PowerShell') end
  az.status = 'starting'
  az.err = ''
  az.started_at = os.clock()
  az.tick_t = os.clock()
end

function azEnsure()
  if az.status ~= 'idle' or os.clock() < az.hold then return end
  if azFilesOk() then azStartHelper() else azStartSetup() end
end

function azRestart()
  if az.cmd then azSend('quit') end
  if az.old_proc ~= nil then azCloseProc(az.old_proc, true) end
  az.old_proc, az.old_kill = az.hproc, os.clock() + 3
  az.hproc = nil
  az.status = 'idle'
  az.shown = false
  az.pending, az.hold = true, os.clock() + 1.2
  az.tries = 1
  az.gave_up = false
end

function azPollState()
  if az.old_proc ~= nil and os.clock() >= az.old_kill then
    azCloseProc(az.old_proc, true)
    az.old_proc = nil
  end
  if az.pending and az.status == 'idle' and os.clock() >= az.hold then
    az.pending = false
    azEnsure()
  end
  if az.status == 'setup' then
    local s = azRead(AZ_DIR .. '\\setup_status.txt')
    if s and s:find('^ok') then
      if azFilesOk() then azStartHelper() else azFail('компоненты не найдены после загрузки') end
    elseif s and s:find('^error') then
      azFail('загрузка компонентов: ' .. s:gsub('^error%s*', ''))
    elseif os.clock() - az.setup_at > 180 then
      azFail('загрузка компонентов заняла слишком много времени')
    end
    return
  end
  if az.status ~= 'starting' and az.status ~= 'ready' then return end
  local s = azRead(az.state)
  if not s then
    if az.status == 'starting' and os.clock() - az.started_at > 60 then azFail('помощник не запустился') end
    return
  end
  local st = azParseState(s)
  if st.fatal then return azFail(st.fatal) end
  if st.recover then
    azLog('recover: ' .. tostring(st.recover))
    azKillHelper()
    az.status = 'idle'
    az.pending, az.hold = true, os.clock() + 1.2
    return
  end
  if st.tick and st.tick ~= az.tick then
    az.tick = st.tick
    az.tick_t = os.clock()
  end
  if st.ready == '1' and az.status ~= 'ready' then az.status = 'ready' end
  if st.loaded == '1' and not az.loaded then az.loaded = true end
  if st.frame == '1' then az.frame = true end
  if st.title then az.title = st.title end
  if az.status == 'ready' and az.want_url ~= '' and not az.ready_nav then
    az.ready_nav = true
    azSend('nav ' .. az.want_url)
  end
  if os.clock() - az.tick_t > 12 and az.status == 'ready' then
    azLog('браузер не отвечает, перезапуск')
    azRestart()
  end
end

function azClamp(v, a, b)
  return math.max(a, math.min(b, v))
end

function azKeyMods()
  local m = 0
  if user32.GetAsyncKeyState(0x10) < 0 then m = m + 8 end
  if user32.GetAsyncKeyState(0x11) < 0 then m = m + 2 end
  if user32.GetAsyncKeyState(0x12) < 0 then m = m + 1 end
  return m
end

function azFeedWeb(px, py, sw, sh, hov)
  if not az.gm or not mouseHold or sw < 1 or sh < 1 then return end
  local lib = imgui
  if not lib then return end
  local mp = lib.GetMousePos()
  local lx = azClamp(mp.x - px, 0, sw - 1)
  local ly = azClamp(mp.y - py, 0, sh - 1)
  local bx, by = math.floor(lx), math.floor(ly)
  local fx = azClamp(math.floor(lx / sw * 10000 + 0.5), 0, 10000)
  local fy = azClamp(math.floor(ly / sh * 10000 + 0.5), 0, 10000)
  local m = azKeyMods()
  local held = false
  for b = 0, 2 do
    if hov and lib.IsMouseClicked(b) then
      az.cap[b] = true
      az.kb = true
      az.web_hit = true
      local t, c = os.clock(), az.clk
      if c and c.b == b and t - c.t < 0.4 and math.abs(bx - c.x) < 6 and math.abs(by - c.y) < 6 then
        c.n = math.min(c.n + 1, 3)
      else
        c = { n = 1, b = b }
        az.clk = c
      end
      c.t, c.x, c.y = t, bx, by
      azSend(string.format('md %d %d %s %d %d', fx, fy, AZ_BTN[b], m, c.n))
    elseif az.cap[b] and not lib.IsMouseDown(b) then
      az.cap[b] = nil
      azSend(string.format('mu %d %d %s %d %d', fx, fy, AZ_BTN[b], m, az.clk and az.clk.n or 1))
    end
    if az.cap[b] then held = true end
  end
  if hov or held then
    if bx ~= az.mx or by ~= az.my then
      az.mx, az.my = bx, by
      azSend(string.format('mm %d %d', fx, fy))
    end
    local wheel = lib.GetIO().MouseWheel
    if hov and wheel ~= 0 then
      azSend(string.format('mw %d %d %d %d', fx, fy, math.floor(-wheel * 100), m))
    end
  elseif az.was_hov then
    azSend('ml')
    az.mx, az.my = -1, -1
  end
  az.was_hov = hov or held
end

function azSyncView()
  if az.status ~= 'starting' and az.status ~= 'ready' then return end
  azSendK('frame', 'frame none 0 0 0 0 0 0 0 0 1.0000')
  azSendK('lock', 'lock 0')
  azSendK('vol', 'vol 60')
  azSendK('mute', 'mute 0')
  if az.status ~= 'ready' then return end
  if not cefOpen then
    azSendK('view', 'view hide')
    azSendK('inter', 'inter 0')
    az.shown = false
    return
  end
  local rx, ry = getScreenResolution()
  local x = math.floor(cefView.x or 40)
  local y = math.floor(cefView.y or 80)
  local w = math.floor(cefView.w or CEF_W)
  local h = math.floor(cefView.h or CEF_H)
  azSendK('view', string.format('view float %d %d %d %d %d %d', x, y, w, h, rx, ry))
  az.shown = true
  if az.gm then
    azSendK('inter', 'inter 1')
  else
    azSendK('inter', 'inter ' .. (mouseHold and 1 or 0))
  end
end

function imguiScale(lib)
  local sw, sh = getScreenResolution()
  local io = lib.GetIO and lib.GetIO() or nil
  if not io or not io.DisplaySize or not sw or sw < 1 or not sh or sh < 1 then
    return 1, 1
  end
  local sx = io.DisplaySize.x / sw
  local sy = io.DisplaySize.y / sh
  if sx ~= sx or sy ~= sy or sx < 0.5 or sx > 3 or sy < 0.5 or sy > 3 then
    return 1, 1
  end
  if math.abs(sx - 1) < 0.04 then sx = 1 end
  if math.abs(sy - 1) < 0.04 then sy = 1 end
  return sx, sy
end

function browserOrigin(w, h)
  local sw, sh = getScreenResolution()
  w = w or CEF_W
  h = h or CEF_H
  local x = math.floor(sw / 2 + 64)
  local y = math.floor((sh - h) / 2)
  if x < 0 then x = 0 end
  if y < 0 then y = 0 end
  if x + w > sw then x = math.max(0, sw - w) end
  if y + h > sh then y = math.max(0, sh - h) end
  return x, y
end

function clampSize(w, h)
  local sw, sh = getScreenResolution()
  w = math.floor(w)
  h = math.floor(h)
  local maxW = math.min(CEF_MAX_W, math.max(CEF_MIN_W, sw - 8))
  local maxH = math.min(CEF_MAX_H, math.max(CEF_MIN_H, sh - 40))
  if w < CEF_MIN_W then w = CEF_MIN_W end
  if h < CEF_MIN_H then h = CEF_MIN_H end
  if w > maxW then w = maxW end
  if h > maxH then h = maxH end
  return w, h
end

function savedBrowserSize()
  local w = tonumber(cfg.referenz.cefW) or CEF_W
  local h = tonumber(cfg.referenz.cefH) or CEF_H
  local cw, ch = clampSize(w, h)
  if cw ~= w or ch ~= h then
    cfg.referenz.cefW = cw
    cfg.referenz.cefH = ch
    saveCfg()
  end
  return cw, ch
end

function clampBrowser(x, y, w, h)
  local sw, sh = getScreenResolution()
  w = w or cefView.w or CEF_W
  h = h or cefView.h or CEF_H
  x = math.floor(x)
  y = math.floor(y)
  if x < 0 then x = 0 end
  if y < 32 then y = 32 end
  if x > sw - w then x = math.max(0, sw - w) end
  if y > sh - h then y = math.max(32, sh - h) end
  return x, y
end

function commitBrowserSize()
  local w, h = clampSize(cefView.w or CEF_W, cefView.h or CEF_H)
  cefView.w, cefView.h = w, h
  cefCommitW, cefCommitH = w, h
  cfg.referenz.cefW = w
  cfg.referenz.cefH = h
  saveCfg()
  az.sent.view = nil
end

function browseNav(url)
  az.want_url = tostring(url or '')
  az.ready_nav = false
  if az.status == 'ready' and az.want_url ~= '' then
    az.ready_nav = true
    azSend('nav ' .. az.want_url)
  end
end

function openReferenzCef(url)
  local blobs = azLoadBlobs()
  if not blobs then
    chat(az.err ~= '' and az.err or 'данные браузера повреждены')
    return
  end
  local spawn = not cefOpen
  if spawn then
    local bw, bh = savedBrowserSize()
    cefOpen = true
    cefView.w, cefView.h = bw, bh
    cefCommitW, cefCommitH = bw, bh
    local ox, oy = browserOrigin(bw, bh)
    local sx, sy = tonumber(cfg.referenz.cefX), tonumber(cfg.referenz.cefY)
    if sx and sy and sx >= 0 and sy >= 0 then
      ox, oy = clampBrowser(sx, sy, bw, bh)
    end
    cefView.x, cefView.y = ox, oy
    az.sent = {}
    if az.status == 'idle' or az.status == 'fatal' then
      az.status = 'idle'
      az.hold = 0
      azEnsure()
    elseif az.status == 'ready' then
      az.sent.view = nil
    end
  end
  browseNav(url)
  cefView.placed = true
  barMouse = mouseHold
  if spawn and not cursorTold then
    cursorTold = true
    chat('Браузер WebView2. Мышь у скрипта, Alt отдаёт её игре')
  end
  if az.status == 'setup' then
    chat('Первый запуск браузера: скачиваю компоненты (~10 МБ)')
  end
end

function closeReferenzCef()
  if not cefOpen then return end
  barMouse = false
  cefOpen = false
  barDragX, barDragY = nil, nil
  dragHeld = false
  barSizeX, barSizeY = nil, nil
  sizeHeld = false
  sizeApply = false
  hub.forum = ''
  az.want_url = ''
  az.ready_nav = false
  az.sent.view = nil
  azSendK('view', 'view hide')
  azSendK('inter', 'inter 0')
  az.shown = false
  for b = 0, 2 do az.cap[b] = nil end
end

function killBrowseHelper()
  if az.cmd then azSend('quit') end
  azKillHelper()
  if az.old_proc ~= nil then azCloseProc(az.old_proc, true) end
  az.old_proc = nil
  az.status = 'idle'
  az.cmd, az.state = nil, nil
end

function pumpBrowse()
  local ok, err = pcall(azPollState)
  if not ok then
    azLog('poll: ' .. tostring(err))
  end
  pcall(azSyncView)
end

function authHead()
  return 'Authorization: Bearer ' .. tostring(cfg.referenz.token or '')
end

function absSite(url)
  url = tostring(url or ''):gsub('\\/', '/')
  if url:find('^https?://') then return url end
  if url:sub(1, 1) ~= '/' then url = '/' .. url end
  return SITE .. url
end

function parseShots(body)
  local list = {}
  local i = 1
  body = tostring(body)
  while #list < 24 do
    local a, b, id, url = body:find('"id"%s*:%s*"(%w+)"%s*,%s*"url"%s*:%s*"([^"]+)"', i)
    if not a then break end
    local window = body:sub(b, b + 700)
    list[#list + 1] = {
      id = id,
      url = absSite(url),
      review = window:find('"review"%s*:%s*true') ~= nil,
    }
    i = b + 1
  end
  return list
end

function parseAlbums(body)
  local list = {}
  local i = 1
  body = tostring(body)
  while #list < 24 do
    local a, b, id = body:find('"id"%s*:%s*"(%w+)"', i)
    if not a then break end
    local window = body:sub(b, b + 800)
    local title = window:match('"title"%s*:%s*"([^"]*)"')
    local count = window:match('"count"%s*:%s*(%d+)')
    local vis = window:match('"visibility"%s*:%s*"(%w+)"') or 'private'
    if title and title ~= '' then
      list[#list + 1] = { id = id, title = title, count = count or '0', vis = vis }
    end
    i = b + 1
  end
  return list
end

local thumbThread = nil
local effilLib = nil
local shrinkShot
pcall(function() effilLib = require('effil') end)

function looksImage(bin)
  if type(bin) ~= 'string' or #bin < 32 then return false end
  if bin:sub(1, 2) == '\255\216' or bin:sub(1, 2) == 'BM' or bin:sub(1, 4) == 'GIF8' then return true end
  if bin:sub(1, 8) == '\137PNG\r\n\26\n' then return true end
  return false
end

function finishThumb(item, id, bin)
  if not (ui.hub and ui.hub[0]) or not looksImage(bin) then
    item.miss = true
    return
  end
  local small = shrinkShot(id, bin)
  if small and looksImage(small) then
    if not stageThumbBytes(id, small) then item.miss = true end
  elseif #bin < 4000000 then
    if not stageThumbBytes(id, bin) then item.miss = true end
  else
    item.miss = true
  end
end

function stageThumbBytes(id, bytes)
  if type(id) ~= 'string' or type(bytes) ~= 'string' then return false end
  if #id == 0 or #id > 39 or #bytes < 32 or #bytes > 4000000 then return false end
  if texFlag[0] ~= 0 then
    hub.raw[id] = bytes
    return true
  end
  ffi.copy(texBuf, bytes, #bytes)
  texLen[0] = #bytes
  hub.pendingId = id
  texFlag[0] = 1
  return true
end

function pumpThumbs()
  local flag = texFlag[0]
  if flag == 2 or flag == 3 then
    if flag == 3 and hub.pendingId then hub.miss[hub.pendingId] = true end
    hub.pendingId = nil
    texFlag[0] = 0
    flag = 0
  end
  if flag ~= 0 then return end
  local id, bytes = nil, nil
  for key, value in pairs(hub.raw) do
    id, bytes = key, value
    break
  end
  if not id then return end
  hub.raw[id] = nil
  if not stageThumbBytes(id, bytes) then hub.miss[id] = true end
end

function bakePendingTex()
  if texFlag[0] ~= 1 or not imgui or not hub.pendingId then return end
  local n = tonumber(texLen[0]) or 0
  local id = hub.pendingId
  local ok, tex = pcall(imgui.CreateTextureFromFileInMemory, texBuf, n)
  if ok and tex ~= nil then
    hub.tex[id] = tex
    texFlag[0] = 2
  else
    texFlag[0] = 3
  end
end

function takeThumb()
  if not ui.hub or not ui.hub[0] then return end
  if thumbThread then
    local st, err = nil, nil
    pcall(function()
      st, err = thumbThread.th:status()
    end)
    if err or st == 'failed' or st == 'canceled' then
      thumbThread.item.miss = true
      thumbThread = nil
      return
    end
    if st ~= 'completed' then return end
    local okFlag, info = false, nil
    pcall(function()
      okFlag, info = thumbThread.th:get()
    end)
    local bin = nil
    if okFlag and type(info) == 'string' then
      local f = io.open(info, 'rb')
      if f then
        bin = f:read('*a')
        f:close()
      end
    end
    finishThumb(thumbThread.item, thumbThread.id, bin)
    thumbThread = nil
    return
  end
  local item, seen = nil, 0
  for _, shot in ipairs(hub.shots) do
      if shot.id == hub.pick and not hub.tex[shot.id] and not hub.raw[shot.id] and not shot.miss and not hub.miss[shot.id] then
      item = shot
      break
    end
  end
  if not item then
    for _, shot in ipairs(hub.shots) do
      seen = seen + 1
      if seen > 12 then break end
      if not hub.tex[shot.id] and not hub.raw[shot.id] and not shot.miss and not hub.miss[shot.id] then
        item = shot
        break
      end
    end
  end
  if not item then
    for _, shot in ipairs(hub.sideShots or {}) do
      if not hub.tex[shot.id] and not hub.raw[shot.id] and not shot.miss and not hub.miss[shot.id] then
        item = shot
        break
      end
    end
  end
  if not item then return end
  if not effilLib then
    item.miss = true
    return
  end
  local url, token, id = item.url, item.pub and '' or tostring(cfg.referenz.token or ''), item.id
  local dir = getWorkingDirectory() .. '\\referenz-cache'
  pcall(function() kernel32.CreateDirectoryA(dir, nil) end)
  local path = dir .. '\\' .. id .. '.bin'
  local ok, th = pcall(function()
    return effilLib.thread(function(photoUrl, photoToken, photoPath)
      local okReq, requests = pcall(require, 'requests')
      if not okReq or not requests then return false, 'no requests' end
      local okHttp, resp = pcall(requests.get, photoUrl, {
        headers = photoToken ~= '' and { ['Authorization'] = 'Bearer ' .. photoToken } or {},
        timeout = 30,
      })
      if not okHttp or not resp or type(resp.text) ~= 'string' or #resp.text < 32 then
        return false, 'empty'
      end
      local f = io.open(photoPath, 'wb')
      if not f then return false, 'file' end
      f:write(resp.text)
      f:close()
      return true, photoPath
    end)(url, token, path)
  end)
  if not ok or th == nil then
    item.miss = true
    return
  end
  thumbThread = { th = th, item = item, id = id }
end

function addShots(body)
  local seen = {}
  for _, shot in ipairs(hub.shots) do seen[shot.id] = true end
  for _, shot in ipairs(parseShots(body or '')) do
    local url = shot.url:lower()
    if not seen[shot.id] and #hub.shots < 18 and not url:find('%.mp4', 1, true) and not url:find('%.webm', 1, true) then
      hub.shots[#hub.shots + 1] = shot
      seen[shot.id] = true
    end
  end
  local keep = false
  for _, shot in ipairs(hub.shots) do
    if shot.id == hub.pick then keep = true break end
  end
  if not keep then hub.pick = hub.shots[1] and hub.shots[1].id or nil end
end

function loadHub()
  if useImgbb() then
    hub.shots = readImgbbShots()
    hub.albums = {}
    hub.openAlbum = nil
    hub.side = 'shots'
    hub.sideAlbum = nil
    hub.tab = 'shots'
    hub.note = #hub.shots == 0 and 'Пока нет кадров ImgBB. Нажмите F8' or ''
    hub.loading = false
    return
  end
  if hub.loading or not loggedIn() then return end
  hub.loading = true
  if not useImgbb() then hub.note = '' end
  lua_thread.create(function()
    wait(0)
    local hdr = authHead()
    local shots = httpGet(SITE .. '/api/inbox', hdr)
    wait(0)
    local albums = httpGet(SITE .. '/api/albums?user=' .. tostring(cfg.referenz.username), hdr)
    if not shots then
      if not useImgbb() then
        hub.note = 'Нет связи с сайтом'
        hub.shots = {}
      end
      hub.albums = {}
    else
      hub.albums = parseAlbums(albums or '')
      if not useImgbb() then
        hub.shots = {}
        addShots(shots)
        for i, album in ipairs(hub.albums) do
          if #hub.shots >= 12 or i > 4 then break end
          wait(0)
          addShots(httpGet(SITE .. '/api/albums/' .. album.id, hdr) or '')
        end
        if #hub.shots == 0 and #hub.albums == 0 then
          hub.note = 'Пока пусто'
        end
      end
    end
    hub.loading = false
  end)
end

function shrinkShot(id, bytes)
  if not gdiplus or not bytes then return nil end
  local dir = getWorkingDirectory() .. '\\referenz-cache'
  pcall(function() kernel32.CreateDirectoryA(dir, nil) end)
  local ext = '.jpg'
  if bytes:sub(1, 8) == '\137PNG\r\n\26\n' then ext = '.png'
  elseif bytes:sub(1, 4) == 'RIFF' and bytes:sub(9, 12) == 'WEBP' then ext = '.webp'
  elseif bytes:sub(1, 2) ~= '\255\216' then ext = '.img' end
  local src = dir .. '\\' .. id .. ext
  local dst = dir .. '\\' .. id .. '.thumb.jpg'
  local f = io.open(src, 'wb')
  if not f then return nil end
  f:write(bytes)
  f:close()
  local image = ffi.new('void*[1]')
  if gdiplus.GdipLoadImageFromFile(wide(src), image) ~= 0 or image[0] == nil then
    return nil
  end
  local w = ffi.new('unsigned int[1]')
  local h = ffi.new('unsigned int[1]')
  gdiplus.GdipGetImageWidth(image[0], w)
  gdiplus.GdipGetImageHeight(image[0], h)
  local tw, th = tonumber(w[0]) or 1, tonumber(h[0]) or 1
  local edge = 480
  if tw > edge or th > edge then
    if tw >= th then
      th = math.max(1, math.floor(th * edge / tw))
      tw = edge
    else
      tw = math.max(1, math.floor(tw * edge / th))
      th = edge
    end
  end
  local thumb = ffi.new('void*[1]')
  local status = gdiplus.GdipGetImageThumbnail(image[0], tw, th, thumb, nil, nil)
  gdiplus.GdipDisposeImage(image[0])
  if status ~= 0 or thumb[0] == nil then return nil end
  status = gdiplus.GdipSaveImageToFile(thumb[0], wide(dst), jpegClsid, nil)
  gdiplus.GdipDisposeImage(thumb[0])
  if status ~= 0 then return nil end
  local rf = io.open(dst, 'rb')
  if not rf then return nil end
  local out = rf:read('*a')
  rf:close()
  if not out or #out < 32 then return nil end
  return out
end

local clipPending = nil

pcall(ffi.cdef, [[
  int OpenClipboard(void* hwnd);
  int CloseClipboard(void);
  int EmptyClipboard(void);
  void* SetClipboardData(unsigned int format, void* mem);
  void* GlobalAlloc(unsigned int flags, unsigned long bytes);
  void* GlobalLock(void* mem);
  int GlobalUnlock(void* mem);
  void* GlobalFree(void* mem);
]])

function clipNull(p)
  if p == nil then return true end
  local ok, n = pcall(function() return tonumber(ffi.cast('uintptr_t', p)) end)
  return not ok or n == nil or n == 0
end

function writeClipboard(text)
  text = tostring(text or '')
  if text == '' then return false end
  local GMEM_MOVEABLE = 2
  local function alloc(bytes)
    local hmem = kernel32.GlobalAlloc(GMEM_MOVEABLE, bytes)
    if clipNull(hmem) then return nil end
    local ptr = kernel32.GlobalLock(hmem)
    if clipNull(ptr) then
      kernel32.GlobalFree(hmem)
      return nil
    end
    return hmem, ptr
  end
  local ansi, ansiPtr = alloc(#text + 1)
  local wideMem, widePtr = alloc((#text + 1) * 2)
  if ansi == nil or wideMem == nil then
    if ansi ~= nil then
      kernel32.GlobalUnlock(ansi)
      kernel32.GlobalFree(ansi)
    end
    if wideMem ~= nil then
      kernel32.GlobalUnlock(wideMem)
      kernel32.GlobalFree(wideMem)
    end
    return false
  end
  ffi.copy(ansiPtr, text)
  kernel32.GlobalUnlock(ansi)
  local wide = ffi.cast('unsigned short*', widePtr)
  for i = 1, #text do
    wide[i - 1] = text:byte(i)
  end
  wide[#text] = 0
  kernel32.GlobalUnlock(wideMem)
  if user32.OpenClipboard(nil) == 0 then
    kernel32.GlobalFree(ansi)
    kernel32.GlobalFree(wideMem)
    return false
  end
  user32.EmptyClipboard()
  local a = user32.SetClipboardData(1, ansi)
  local w = user32.SetClipboardData(13, wideMem)
  user32.CloseClipboard()
  if clipNull(a) then kernel32.GlobalFree(ansi) end
  if clipNull(w) then kernel32.GlobalFree(wideMem) end
  return not clipNull(a) or not clipNull(w)
end

function hubClip(url)
  clipPending = tostring(url or '')
end

function flushClip()
  if not clipPending or clipPending == '' then return end
  local ok, done = pcall(writeClipboard, clipPending)
  if ok and done then clipPending = nil end
end

pcall(ffi.cdef, 'short __stdcall GetAsyncKeyState(int vKey);')

function keyDown(vk)
  local ok, state = pcall(user32.GetAsyncKeyState, vk)
  if ok and state ~= nil and (tonumber(state) or 0) < 0 then return true end
  return type(isKeyDown) == 'function' and isKeyDown(vk) or false
end

function altHeld()
  return keyDown(0x12) or keyDown(0xA4) or keyDown(0xA5)
end

function apiPost(path, payload)
  return httpPost(
    SITE .. path,
    'Content-Type: application/json\r\n' .. authHead(),
    payload or '{}'
  )
end

function readErr(body)
  if not body or body == '' then return 'Нет связи с сайтом' end
  local err = body:match('"error"%s*:%s*"(.-)"')
  if not err then return nil end
  return (err:gsub('\\/', '/'))
end

function visName(vis)
  if vis == 'link' then return 'По ссылке' end
  if vis == 'public' then return 'Лента' end
  return 'Только я'
end

function shotsFrom(body, cap)
  local list = {}
  cap = cap or 24
  for _, shot in ipairs(parseShots(body or '')) do
    local url = shot.url:lower()
    if #list < cap and not url:find('%.mp4', 1, true) and not url:find('%.webm', 1, true) then
      list[#list + 1] = shot
    end
  end
  return list
end

function refreshAlbums()
  local albums = httpGet(SITE .. '/api/albums?user=' .. tostring(cfg.referenz.username), authHead())
  hub.albums = parseAlbums(albums or '')
end

function openAlbum(album)
  hub.openAlbum = {
    id = album.id,
    title = album.title or '',
    count = album.count or '0',
    vis = album.vis or 'private',
    desc = album.desc or '',
  }
  hub.albumShots = {}
  hub.albumMsg = ''
  hub.confirmDel = false
  hub.moveOpen = false
  hub.pick = nil
  local id = album.id
  lua_thread.create(function()
    wait(0)
    local body = httpGet(SITE .. '/api/albums/' .. id, authHead()) or ''
    if not hub.openAlbum or hub.openAlbum.id ~= id then return end
    local err = readErr(body)
    if err then
      hub.albumMsg = err
      return
    end
    local vis = body:match('"visibility"%s*:%s*"(%w+)"')
    local title = body:match('"title"%s*:%s*"([^"]*)"')
    local desc = body:match('"description"%s*:%s*"([^"]*)"')
    if vis then hub.openAlbum.vis = vis end
    if title and title ~= '' then hub.openAlbum.title = title end
    hub.openAlbum.desc = desc or ''
    hub.albumShots = shotsFrom(body, 24)
    hub.openAlbum.count = tostring(#hub.albumShots)
    hub.pick = hub.albumShots[1] and hub.albumShots[1].id or nil
    if ui.albumTitle then setBuf(ui.albumTitle, hub.openAlbum.title, 81) end
    if ui.albumDesc then setBuf(ui.albumDesc, hub.openAlbum.desc, 281) end
  end)
end

function loadSideAlbum(album)
  hub.sideAlbum = { id = album.id, title = album.title or '' }
  hub.sideShots = {}
  hub.sideNote = 'Загрузка…'
  local id = album.id
  lua_thread.create(function()
    wait(0)
    local body = httpGet(SITE .. '/api/albums/' .. id, authHead()) or ''
    if not hub.sideAlbum or hub.sideAlbum.id ~= id then return end
    local err = readErr(body)
    if err then
      hub.sideNote = err
      return
    end
    hub.sideShots = shotsFrom(body, 24)
    hub.sideNote = #hub.sideShots == 0 and 'В альбоме пусто' or ''
  end)
end

function createAlbum()
  if hub.albumBusy or not ui.albumTitle then return end
  local title = ffi.string(ui.albumTitle):gsub('^%s+', ''):gsub('%s+$', '')
  local desc = ui.albumDesc and ffi.string(ui.albumDesc) or ''
  desc = desc:gsub('^%s+', ''):gsub('%s+$', '')
  if title == '' then
    hub.albumMsg = 'Нужно название'
    return
  end
  hub.albumBusy = true
  hub.albumMsg = ''
  lua_thread.create(function()
    wait(0)
    local body = apiPost('/api/albums', '{"title":"' .. jsonEscape(title) .. '","description":"' .. jsonEscape(desc) .. '"}')
    local err = readErr(body)
    hub.albumBusy = false
    if err then
      hub.albumMsg = err
      return
    end
    local id = tostring(body or ''):match('"id"%s*:%s*"(%w+)"')
    if ui.albumTitle then setBuf(ui.albumTitle, '', 81) end
    if ui.albumDesc then setBuf(ui.albumDesc, '', 281) end
    chat('Альбом создан')
    refreshAlbums()
    if id then
      openAlbum({ id = id, title = title, count = '0', vis = 'private', desc = desc })
    end
  end)
end

function saveAlbum()
  local album = hub.openAlbum
  if not album or hub.albumBusy or not ui.albumTitle then return end
  local title = ffi.string(ui.albumTitle):gsub('^%s+', ''):gsub('%s+$', '')
  local desc = ui.albumDesc and ffi.string(ui.albumDesc) or ''
  desc = desc:gsub('^%s+', ''):gsub('%s+$', '')
  if title == '' then
    hub.albumMsg = 'Нужно название'
    return
  end
  local vis = album.vis or 'private'
  hub.albumBusy = true
  lua_thread.create(function()
    wait(0)
    local body = apiPost(
      '/api/albums/' .. album.id .. '/update',
      '{"title":"' .. jsonEscape(title) .. '","description":"' .. jsonEscape(desc) .. '","visibility":"' .. vis .. '"}'
    )
    hub.albumBusy = false
    local err = readErr(body)
    if err then
      hub.albumMsg = err
      return
    end
    album.title = title
    album.desc = desc
    hub.albumMsg = 'Сохранено'
    chat('Альбом сохранён')
    refreshAlbums()
  end)
end

function setAlbumVis(vis)
  local album = hub.openAlbum
  if not album or hub.albumBusy then return end
  hub.albumBusy = true
  lua_thread.create(function()
    wait(0)
    local body = apiPost(
      '/api/albums/' .. album.id .. '/update',
      '{"title":"' .. jsonEscape(album.title or '') .. '","description":"' .. jsonEscape(album.desc or '') .. '","visibility":"' .. vis .. '"}'
    )
    hub.albumBusy = false
    local err = readErr(body)
    if err then
      hub.albumMsg = err
      chat(err)
      return
    end
    album.vis = vis
    hub.albumMsg = visName(vis)
    chat('Кто видит: ' .. visName(vis))
    refreshAlbums()
  end)
end

function deleteAlbum()
  local album = hub.openAlbum
  if not album or hub.albumBusy then return end
  if not hub.confirmDel then
    hub.confirmDel = true
    hub.albumMsg = 'Нажмите ещё раз, альбом удалится'
    return
  end
  hub.albumBusy = true
  hub.confirmDel = false
  local id = album.id
  lua_thread.create(function()
    wait(0)
    local body = apiPost('/api/albums/' .. id .. '/delete', '{}')
    hub.albumBusy = false
    local err = readErr(body)
    if err then
      hub.albumMsg = err
      return
    end
    if hub.openAlbum and hub.openAlbum.id == id then
      hub.openAlbum = nil
      hub.albumShots = {}
    end
    hub.albumMsg = ''
    chat('Альбом удалён, снимки снова во входящих')
    refreshAlbums()
  end)
end

function movePhoto(shotId, albumId)
  if hub.albumBusy then return end
  hub.albumBusy = true
  lua_thread.create(function()
    wait(0)
    local body = apiPost('/api/photos/' .. shotId .. '/move', '{"albumId":"' .. albumId .. '"}')
    hub.albumBusy = false
    local err = readErr(body)
    if err then
      chat(err)
      return
    end
    local nextShots = {}
    for _, shot in ipairs(hub.shots) do
      if shot.id ~= shotId then nextShots[#nextShots + 1] = shot end
    end
    hub.shots = nextShots
    if hub.pick == shotId then hub.pick = hub.shots[1] and hub.shots[1].id or nil end
    hub.moveOpen = false
    chat('Снимок перенесён в альбом')
    refreshAlbums()
  end)
end

function photoToInbox(shotId)
  if hub.albumBusy then return end
  hub.albumBusy = true
  lua_thread.create(function()
    wait(0)
    local body = apiPost('/api/photos/' .. shotId .. '/inbox', '{}')
    hub.albumBusy = false
    local err = readErr(body)
    if err then
      hub.albumMsg = err
      return
    end
    local nextShots = {}
    for _, shot in ipairs(hub.albumShots) do
      if shot.id ~= shotId then nextShots[#nextShots + 1] = shot end
    end
    hub.albumShots = nextShots
    if hub.openAlbum then hub.openAlbum.count = tostring(#hub.albumShots) end
    if hub.pick == shotId then hub.pick = hub.albumShots[1] and hub.albumShots[1].id or nil end
    chat('Снимок снова во входящих')
    refreshAlbums()
  end)
end

local ensureTex
function drawShotPane(lib, list, kind)
  if hub.pick then ensureTex(hub.pick) end
  lib.BeginChild('##shotlist', lib.ImVec2(188, -1), true)
  if #list == 0 then
    lib.TextDisabled(kind == 'album' and 'В альбоме пусто' or 'Пока пусто')
  end
  for _, item in ipairs(list) do
    if lib.PushIDStr then lib.PushIDStr(item.id) end
    local tex = ensureTex(item.id)
    local picked = item.id == hub.pick
    if tex and lib.ImageButton(tex, lib.ImVec2(160, 90)) then
      hub.pick = item.id
      hub.moveOpen = false
    elseif lib.Button(item.id:sub(1, 8), lib.ImVec2(160, 28)) then
      hub.pick = item.id
      hub.moveOpen = false
    end
    if picked then lib.TextDisabled('этот кадр') end
    if item.review and lib.TextColored then
      lib.TextColored(v4(lib, PAL.gold), 'на проверке')
    end
    if lib.PopID then lib.PopID() end
  end
  lib.EndChild()
  lib.SameLine(0, 8)
  lib.BeginChild('##shotview', lib.ImVec2(0, -1), false)
  local shot = nil
  for _, item in ipairs(list) do
    if item.id == hub.pick then shot = item break end
  end
  if not shot then
    lib.TextDisabled('Выберите снимок слева')
  else
    local tex = hub.tex[shot.id]
    if tex then
      lib.Image(tex, lib.ImVec2(420, 250))
    elseif shot.miss then
      lib.TextDisabled('Кадр не открылся, ссылку всё равно можно скопировать')
    else
      lib.TextDisabled('Кадр загружается…')
    end
    lib.TextDisabled(shot.id)
    if shot.review and lib.TextColored then
      lib.TextColored(v4(lib, PAL.gold), 'На проверке. В ленту попадёт после решения.')
    end
    if goldBtn(lib, 'Копировать ссылку', 220, 32) then
      hubClip(shot.link or (SITE .. '/p/' .. shot.id))
      chat('Ссылка на кадр скопирована')
    end
    if kind == 'inbox' and not useImgbb() then
      lib.SameLine()
      if lib.Button('В альбом', lib.ImVec2(140, 32)) then
        hub.moveOpen = not hub.moveOpen
      end
      if hub.moveOpen then
        if #hub.albums == 0 then
          lib.TextDisabled('Сначала создайте альбом на вкладке Альбомы')
        end
        for _, album in ipairs(hub.albums) do
          if lib.Button(album.title, lib.ImVec2(-1, 28)) then
            movePhoto(shot.id, album.id)
          end
        end
      end
    else
      lib.SameLine()
      if lib.Button('Убрать', lib.ImVec2(140, 32)) then
        photoToInbox(shot.id)
      end
    end
  end
  lib.EndChild()
end

function ensureTex(id)
  return hub.tex[id]
end

function openReferenzHub()
  if ui.ready ~= 'mimgui' or not ui.hub then
    chat('Окно сайта нужно открывать с mimgui')
    return
  end
  closeWindow()
  ui.hub[0] = true
  mouseHold = true
  loadHub()
end

function closeReferenzHub()
  closeReferenzCef()
  mouseHold = false
  if ui.hub then ui.hub[0] = false end
end

function drawForumRail(lib, sw)
  if ui.rail then ui.rail[0] = true end
  local railW = 132
  local railX = sw - railW - 12
  local viewX = cefView.x or 0
  if viewX + (cefView.w or CEF_W) > railX - 8 then railX = 8 end
  lib.SetNextWindowPos(lib.ImVec2(railX, 12), 1)
  lib.SetNextWindowSize(lib.ImVec2(railW, 280), 1)
  if not lib.Begin('##referenzrail', ui.rail, windowFlags(lib)) then
    lib.End()
    return
  end
  lib.TextDisabled('форумы')
  for _, forum in ipairs(FORUMS) do
    if hub.forum == forum.name then
      goldBtn(lib, forum.name, -1, 32)
    elseif lib.Button(forum.name, lib.ImVec2(-1, 32)) then
      hub.forum = forum.name
      openReferenzCef(forum.url)
    end
  end
  if lib.Button('Закрыть', lib.ImVec2(-1, 28)) then
    wantCefClose = true
  end
  lib.End()
end

function drawForumSide(lib)
  if not ui.side then return end
  ui.side[0] = true
  local sx, sy = imguiScale(lib)
  local panelW = 210
  local bw = cefView.w or CEF_W
  local bh = cefView.h or CEF_H
  local x = cefView.x or 40
  local y = cefView.y or 80
  local px = x * sx - panelW - 8
  if px < 4 then px = 4 end
  lib.SetNextWindowPos(lib.ImVec2(px, y * sy), 1)
  lib.SetNextWindowSize(lib.ImVec2(panelW, math.max(220, bh * sy)), 1)
  local nCol, nVar = pushHardStyle(lib)
  local flags = 1 + 2 + 4 + 32
  if not mouseHold then flags = flags + 512 end
  if not lib.Begin('##referenzside', ui.side, flags) then
    lib.End()
    popHardStyle(lib, nCol, nVar)
    return
  end
  local function copyShot(item)
    hubClip(item.link or (SITE .. '/p/' .. item.id))
    chat('Ссылка на кадр скопирована')
  end
  local function shotRow(item)
    if lib.PushIDStr then lib.PushIDStr('s' .. item.id) end
    local tex = ensureTex(item.id)
    local rowH = 36
    if tex and lib.ImageButton(tex, lib.ImVec2(64, rowH)) then copyShot(item) end
    if tex then lib.SameLine() end
    local label = item.id:sub(1, 10)
    if lib.Button(label, lib.ImVec2(tex and 112 or 184, rowH)) then copyShot(item) end
    if item.review and lib.TextColored then
      lib.TextColored(v4(lib, PAL.gold), 'на проверке')
    end
    if lib.PopID then lib.PopID() end
  end
  if useImgbb() then
    hub.side = 'shots'
    hub.sideAlbum = nil
  end
  if hub.side == 'shots' then
    goldBtn(lib, 'Снимки', 96, 26)
  elseif lib.Button('Снимки', lib.ImVec2(96, 26)) then
    hub.side = 'shots'
    hub.sideAlbum = nil
  end
  if not useImgbb() then
    lib.SameLine()
    if hub.side == 'albums' then
      goldBtn(lib, 'Альбомы', 96, 26)
    elseif lib.Button('Альбомы', lib.ImVec2(96, 26)) then
      hub.side = 'albums'
    end
  end
  if lib.Button('Обновить', lib.ImVec2(-1, 22)) then loadHub() end
  lib.BeginChild('##sidelist', lib.ImVec2(0, -1), false)
  if hub.loading and not useImgbb() then
    lib.TextDisabled('Загрузка…')
  elseif hub.side == 'shots' then
    if #hub.shots == 0 then lib.TextDisabled(hub.note ~= '' and hub.note or 'Пока пусто') end
    for _, item in ipairs(hub.shots) do
      shotRow(item)
    end
  elseif hub.sideAlbum then
    if lib.Button('Назад', lib.ImVec2(70, 24)) then
      hub.sideAlbum = nil
      hub.sideShots = {}
      hub.sideNote = ''
    end
    lib.SameLine()
    if lib.Button('Ссылка', lib.ImVec2(80, 24)) then
      hubClip(SITE .. '/a/' .. hub.sideAlbum.id)
      chat('Ссылка на альбом скопирована')
    end
    lib.TextDisabled(hub.sideAlbum.title or '')
    if hub.sideNote ~= '' then lib.TextDisabled(hub.sideNote) end
    for _, item in ipairs(hub.sideShots) do
      shotRow(item)
    end
  else
    if useImgbb() and not loggedIn() then
      lib.TextDisabled('Альбомы есть только на сайте.')
      lib.TextDisabled('Кадры ImgBB — во вкладке Снимки.')
    elseif #hub.albums == 0 then
      lib.TextDisabled(hub.note ~= '' and hub.note or 'Альбомов нет')
    end
    for _, album in ipairs(hub.albums) do
      if lib.PushIDStr then lib.PushIDStr('a' .. album.id) end
      local title = album.title or 'альбом'
      if #title > 16 then title = title:sub(1, 16) end
      if lib.Button(title, lib.ImVec2(120, 28)) then
        hubClip(SITE .. '/a/' .. album.id)
        chat('Ссылка на альбом скопирована')
      end
      lib.SameLine()
      if lib.Button('кадры', lib.ImVec2(58, 28)) then
        loadSideAlbum(album)
      end
      if lib.PopID then lib.PopID() end
    end
  end
  lib.EndChild()
  lib.End()
  popHardStyle(lib, nCol, nVar)
end

function drawBrowseHit(lib)
  if not cefOpen or not mouseHold or not az.gm then return end
  local sx, sy = imguiScale(lib)
  local x = (cefView.x or 40) * sx
  local y = (cefView.y or 80) * sy
  local w = (cefView.w or CEF_W) * sx
  local h = (cefView.h or CEF_H) * sy
  lib.SetNextWindowPos(lib.ImVec2(x, y), 1)
  lib.SetNextWindowSize(lib.ImVec2(w, h), 1)
  local flags = 1 + 2 + 4 + 8 + 16 + 128
  if lib.Begin('##azhit', nil, flags) then
    if lib.InvisibleButton then
      lib.InvisibleButton('##azweb', lib.ImVec2(w, h))
    else
      lib.Dummy(lib.ImVec2(w, h))
    end
    local hov = (lib.IsItemHovered and lib.IsItemHovered()) or (lib.IsWindowHovered and lib.IsWindowHovered())
    azFeedWeb(x, y, w, h, hov)
  end
  lib.End()
end

function drawForumBar(lib)
  if not ui.cefBar then return end
  ui.cefBar[0] = true
  local sx, sy = imguiScale(lib)
  local barH = 32
  local bw = cefView.w or CEF_W
  local bh = cefView.h or CEF_H
  local x = cefView.x or 40
  local y = cefView.y or 80
  lib.SetNextWindowPos(lib.ImVec2(x * sx, math.max(0, y * sy - barH)), 1)
  lib.SetNextWindowSize(lib.ImVec2(math.max(48, bw * sx), barH), 1)
  local nCol, nVar = pushHardStyle(lib)
  local barFlags = 1 + 2 + 4 + 32
  if not mouseHold then barFlags = barFlags + 512 end
  if not lib.Begin('##referenzbar', ui.cefBar, barFlags) then
    lib.End()
  else
    lib.Button('Тащи', lib.ImVec2(math.max(48, bw * sx - 368), 22))
    local dragging = lib.IsItemActive() or (dragHeld and keyDown(0x01))
    if dragging then
      dragHeld = true
      local mx, my = lib.GetMousePos().x, lib.GetMousePos().y
      if barDragX then
        local dx = (mx - barDragX) / sx
        local dy = (my - barDragY) / sy
        local nx, ny = clampBrowser(x + dx, y + dy, bw, bh)
        cefView.x, cefView.y = nx, ny
        az.sent.view = nil
        if lib.SetWindowPos then
          lib.SetWindowPos(lib.ImVec2(cefView.x * sx, math.max(0, cefView.y * sy - barH)))
        end
      end
      barDragX, barDragY = mx, my
    else
      if dragHeld then
        cfg.referenz.cefX = cefView.x
        cfg.referenz.cefY = cefView.y
        saveCfg()
        az.sent.view = nil
      end
      dragHeld = false
      barDragX, barDragY = nil, nil
    end
    lib.SameLine()
    lib.Button('Размер', lib.ImVec2(80, 22))
    if lib.IsItemActive() then
      local mx, my = lib.GetMousePos().x, lib.GetMousePos().y
      if barSizeX then
        cefView.w, cefView.h = clampSize(bw + (mx - barSizeX), bh + (my - barSizeY))
        az.sent.view = nil
      end
      barSizeX, barSizeY = mx, my
      sizeHeld = true
    else
      if sizeHeld then sizeApply = true end
      sizeHeld = false
      barSizeX, barSizeY = nil, nil
    end
    lib.SameLine()
    if lib.Button(mouseHold and 'Игра' or 'Писать', lib.ImVec2(80, 22)) then
      setUiMouse(not mouseHold)
    end
    lib.SameLine()
    if lib.Button('Назад', lib.ImVec2(70, 22)) then
      if az.status == 'ready' then
        azSend('back')
      else
        local url = FORUMS[1].url
        for _, forum in ipairs(FORUMS) do
          if forum.name == hub.forum then url = forum.url break end
        end
        browseNav(url)
      end
    end
    lib.SameLine()
    if lib.Button('Закрыть', lib.ImVec2(90, 22)) then wantCefClose = true end
    lib.End()
  end
  popHardStyle(lib, nCol, nVar)
  if not ui.cefBar[0] then
    ui.cefBar[0] = true
    wantCefClose = true
  end
end

function drawReferenzHub()
  local lib = imgui
  if not lib then return end
  hub.decoded = false
  local sw, sh = getScreenResolution()
  if cefOpen then
    drawForumBar(lib)
    drawBrowseHit(lib)
    drawForumSide(lib)
    drawForumRail(lib, sw)
    if az.status == 'setup' or az.status == 'starting' or az.status == 'fatal' then
      lib.SetNextWindowPos(lib.ImVec2(sw / 2, 48), 1, lib.ImVec2(0.5, 0))
      if lib.Begin('##azstat', nil, 1 + 2 + 4 + 32 + 64) then
        if az.status == 'fatal' then
          lib.TextColored(v4(lib, PAL.err), 'Браузер: ' .. tostring(az.err))
        elseif az.status == 'setup' then
          lib.TextDisabled('Скачиваю WebView2…')
        else
          lib.TextDisabled('Запуск браузера…')
        end
      end
      lib.End()
    end
    return
  end
  local nCol, nVar = pushHardStyle(lib)
  local ww, hh = math.min(980, sw - 40), math.min(620, sh - 40)
  lib.SetNextWindowSize(lib.ImVec2(ww, hh), 4)
  lib.SetNextWindowPos(lib.ImVec2(sw / 2, sh / 2), 2, lib.ImVec2(0.5, 0.5))
  if not lib.Begin('##referenzhub', ui.hub, windowFlags(lib)) then
    lib.End()
    popHardStyle(lib, nCol, nVar)
    return
  end
  kickLogo()
  if logo.tex and lib.Image then
    lib.Image(logo.tex, lib.ImVec2(42, 24))
    lib.SameLine(0, 8)
  end
  if lib.TextColored then
    lib.TextColored(v4(lib, PAL.text), 'referenz')
    lib.SameLine(0, 0)
    lib.TextColored(v4(lib, PAL.gold), '.pics')
  else
    lib.Text('referenz.pics')
  end
  lib.SameLine()
  lib.TextDisabled('v' .. tostring(thisScript().version or ''))
  lib.SameLine()
  lib.TextDisabled(tostring(cfg.referenz.username or ''))
  lib.SameLine(ww - 118)
  if lib.Button('Обновить', lib.ImVec2(70, 26)) then loadHub() end
  lib.SameLine()
  if lib.Button('X', lib.ImVec2(28, 26)) then closeReferenzHub() end
  if lib.Dummy then lib.Dummy(lib.ImVec2(0, 4)) end
  drawHostSwitch(lib, 120, 26)
  lib.SameLine()
  if lib.Button('Выйти', lib.ImVec2(90, 26)) then doLogout() end
  if useImgbb() then
    hub.tab = 'shots'
    hub.openAlbum = nil
  end

  local rail = 136
  lib.BeginChild('##site', lib.ImVec2(ww - rail - 36, -1), false)
  if hub.tab == 'shots' then
    if goldBtn(lib, 'Снимки', 110, 28) then end
  elseif lib.Button('Снимки', lib.ImVec2(110, 28)) then
    hub.tab = 'shots'
  end
  if not useImgbb() then
    lib.SameLine(0, 6)
    if hub.tab == 'albums' then
      if goldBtn(lib, 'Альбомы', 110, 28) then
        if hub.openAlbum then
          hub.openAlbum = nil
          hub.confirmDel = false
          hub.albumMsg = ''
          if ui.albumTitle then setBuf(ui.albumTitle, '', 81) end
          if ui.albumDesc then setBuf(ui.albumDesc, '', 281) end
        end
      end
    elseif lib.Button('Альбомы', lib.ImVec2(110, 28)) then
      hub.tab = 'albums'
    end
  end
  if hub.loading then
    lib.TextDisabled('Загрузка…')
  elseif hub.note ~= '' and ((hub.tab == 'shots' and #hub.shots == 0) or (hub.tab == 'albums' and #hub.albums == 0)) then
    lib.TextDisabled(hub.note)
  end
  if hub.tab == 'shots' then
    drawShotPane(lib, hub.shots, 'inbox')
  elseif hub.openAlbum then
    local album = hub.openAlbum
    if lib.Button('К списку', lib.ImVec2(110, 26)) then
      hub.openAlbum = nil
      hub.confirmDel = false
      hub.albumMsg = ''
      if ui.albumTitle then setBuf(ui.albumTitle, '', 81) end
      if ui.albumDesc then setBuf(ui.albumDesc, '', 281) end
    end
    lib.SameLine()
    lib.TextDisabled(visName(album.vis) .. '  ·  ' .. tostring(album.count or #hub.albumShots))
    if ui.albumTitle then
      if lib.InputTextWithHint then
        lib.InputTextWithHint('##atitle', 'название', ui.albumTitle, 81)
      else
        lib.InputText('##atitle', ui.albumTitle, 81)
      end
      if ui.albumDesc then
        if lib.InputTextWithHint then
          lib.InputTextWithHint('##adesc', 'описание', ui.albumDesc, 281)
        else
          lib.InputText('##adesc', ui.albumDesc, 281)
        end
      end
    end
    if goldBtn(lib, 'Сохранить', 120, 28) then saveAlbum() end
    lib.SameLine()
    if lib.Button('Только я', lib.ImVec2(100, 28)) then setAlbumVis('private') end
    lib.SameLine()
    if lib.Button('По ссылке', lib.ImVec2(110, 28)) then setAlbumVis('link') end
    lib.SameLine()
    if lib.Button('Лента', lib.ImVec2(80, 28)) then setAlbumVis('public') end
    if goldBtn(lib, 'Ссылка', 90, 28) then
      hubClip(SITE .. '/a/' .. album.id)
      chat('Ссылка на альбом скопирована')
    end
    lib.SameLine()
    if lib.Button(hub.confirmDel and 'Точно удалить' or 'Удалить', lib.ImVec2(140, 28)) then
      deleteAlbum()
    end
    if hub.albumMsg ~= '' then lib.TextDisabled(hub.albumMsg) end
    drawShotPane(lib, hub.albumShots, 'album')
  else
    lib.TextDisabled('Новый альбом')
    if ui.albumTitle then
      if lib.InputTextWithHint then
        lib.InputTextWithHint('##atitle', 'название', ui.albumTitle, 81)
      else
        lib.InputText('##atitle', ui.albumTitle, 81)
      end
      if ui.albumDesc then
        if lib.InputTextWithHint then
          lib.InputTextWithHint('##adesc', 'описание, можно пустое', ui.albumDesc, 281)
        else
          lib.InputText('##adesc', ui.albumDesc, 281)
        end
      end
    end
    if goldBtn(lib, 'Создать', 140, 32) then createAlbum() end
    if hub.albumMsg ~= '' then lib.TextDisabled(hub.albumMsg) end
    if #hub.albums == 0 and not hub.loading then
      lib.TextDisabled('Альбомов пока нет')
    end
    for _, album in ipairs(hub.albums) do
      if lib.Button(album.title .. '  ·  ' .. album.count .. '  ·  ' .. visName(album.vis), lib.ImVec2(-1, 36)) then
        openAlbum(album)
      end
    end
  end
  lib.EndChild()
  lib.SameLine(0, 8)
  lib.BeginChild('##forums', lib.ImVec2(rail, -1), true)
  if logo.tex and lib.Image then
    local lw = rail - 16
    local lh = math.floor(lw * 9 / 16)
    lib.Image(logo.tex, lib.ImVec2(lw, lh))
    if lib.Dummy then lib.Dummy(lib.ImVec2(0, 6)) end
  end
  lib.TextDisabled('форумы')
  for _, forum in ipairs(FORUMS) do
    if hub.forum == forum.name then
      goldBtn(lib, forum.name, -1, 32)
    elseif lib.Button(forum.name, lib.ImVec2(-1, 32)) then
      hub.forum = forum.name
      openReferenzCef(forum.url)
    end
  end
  drawUpdatePanel(lib, true)
  lib.EndChild()
  lib.End()
  popHardStyle(lib, nCol, nVar)
end

function setUiMouse(on)
  mouseHold = on and true or false
  if cefOpen then
    barMouse = mouseHold
    az.sent.inter = nil
  end
end

function pollAltToggle()
  local down = altHeld()
  local open = (ui.show and ui.show[0]) or (ui.hub and ui.hub[0])
  if down and not altWas and open then
    setUiMouse(not mouseHold)
  end
  altWas = down
end

function scriptWantsMouse()
  if not mouseHold then return false end
  if (ui.show and ui.show[0]) or (ui.hub and ui.hub[0]) then return true end
  return false
end

local uiFrame
if ui.ready == 'mimgui' then
  imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
  end)
  uiFrame = imgui.OnFrame(function()
    pollAltToggle()
    local on = (ui.show and ui.show[0]) or (ui.hub and ui.hub[0])
    if not on then mouseHold = false end
    imgui.DisableInput = false
    return on
  end, function(player)
    local on = (ui.show and ui.show[0]) or (ui.hub and ui.hub[0])
    local want = on and mouseHold
    if player then
      player.HideCursor = not want
      player.LockPlayer = false
    end
    imgui.DisableInput = false
    pcall(bakePendingTex)
    if ui.show and ui.show[0] then pcall(drawLoginWindow) end
    if ui.hub and ui.hub[0] then pcall(drawReferenzHub) end
  end)
end

if ui.ready == 'imgui' then
  function old_imgui.OnDrawFrame()
    if ui.showClassic then
      drawLoginWindow()
    end
  end
end

function ftNum(ft)
  return tonumber(ft.dwHighDateTime) * 4294967296 + tonumber(ft.dwLowDateTime)
end

function nowStamp()
  local ft = ffi.new('FILETIME')
  kernel32.GetSystemTimeAsFileTime(ft)
  return ftNum(ft)
end

function isShotName(name)
  name = tostring(name or ''):lower()
  if name == '' or name == '.' or name == '..' then return false end
  if name == 'sampgui.png' or name:find('sampgui') then return false end
  return name:find('%.png$') or name:find('%.jpe?g$') or name:find('%.bmp$')
end

function screenRoots()
  local roots = {}
  local function add(p)
    if p and p ~= '' then roots[#roots + 1] = p end
  end
  pcall(function()
    add(getGameDirectory() .. '\\screens')
    add(getGameDirectory() .. '\\screenshots')
  end)
  local home = os.getenv('USERPROFILE') or ''
  if home ~= '' then
    local docs = home .. '\\Documents'
    add(docs .. '\\Arizona Games\\screens')
    add(docs .. '\\Arizona Games\\Arizona\\screens')
    add(docs .. '\\Arizona RP\\screens')
    add(docs .. '\\arizona\\screens')
    add(docs .. '\\GTA San Andreas User Files\\screens')
  end
  pcall(function()
    add(getWorkingDirectory() .. '\\screens')
  end)
  return roots
end

function listDir(dir, files, depth)
  if depth > 2 then return end
  local data = ffi.new('WIN32_FIND_DATAA')
  local handle = kernel32.FindFirstFileA(dir .. '\\*', data)
  if handle == nil or handle == INVALID_HANDLE then return end
  repeat
    local name = ffi.string(data.cFileName)
    if name ~= '.' and name ~= '..' then
      local path = dir .. '\\' .. name
          local isDir = math.floor((tonumber(data.dwFileAttributes) or 0) / 16) % 2 == 1
      if isDir then
        listDir(path, files, depth + 1)
      elseif isShotName(name) then
        local size = tonumber(data.nFileSizeLow) or 0
        if size > 8000 then
          files[path] = {
            size = size,
            stamp = ftNum(data.ftLastWriteTime),
          }
        end
      end
    end
  until kernel32.FindNextFileA(handle, data) == 0
  kernel32.FindClose(handle)
end

function indexShots()
  local files = {}
  pcall(function()
    for _, dir in ipairs(screenRoots()) do
      listDir(dir, files, 0)
    end
  end)
  return files
end

function findChanged(before)
  local now = indexShots()
  local best, bestStamp = nil, 0
  for path, info in pairs(now) do
    local old = before[path]
    if (not old or old.size ~= info.size) and info.stamp >= bestStamp then
      best, bestStamp = path, info.stamp
    end
  end
  return best
end

function copyShot(src)
  local ext = src:match('(%.[^\\/%.]+)$') or '.png'
  local dst = getWorkingDirectory() .. '\\referenz_up' .. ext
  local inf = io.open(src, 'rb')
  if not inf then return nil, ext end
  local data = inf:read('*a')
  inf:close()
  if not data or #data < 8000 then return nil, ext end
  local out = io.open(dst, 'wb')
  if not out then return nil, ext end
  out:write(data)
  out:close()
  return dst, ext
end

function u32le(n)
  n = math.floor(tonumber(n) or 0) % 4294967296
  local b1 = n % 256
  n = math.floor(n / 256)
  local b2 = n % 256
  n = math.floor(n / 256)
  local b3 = n % 256
  n = math.floor(n / 256)
  return string.char(b1, b2, b3, n % 256)
end

function takeGdiShot()
  local ok, path = pcall(function()
    local hwnd = user32.GetForegroundWindow()
    if hwnd == nil then
      hwnd = user32.FindWindowA('Grand theft auto San Andreas', nil)
    end
    if hwnd == nil then return nil end
    local rc = ffi.new('RECT')
    if user32.GetClientRect(hwnd, rc) == 0 then return nil end
    local w = tonumber(rc.right - rc.left) or 0
    local h = tonumber(rc.bottom - rc.top) or 0
    if w < 64 or h < 64 or w > 4096 or h > 4096 then return nil end
    local hdc = user32.GetDC(hwnd)
    if hdc == nil then return nil end
    local mem = gdi32.CreateCompatibleDC(hdc)
    local bmp = gdi32.CreateCompatibleBitmap(hdc, w, h)
    local old = gdi32.SelectObject(mem, bmp)
    gdi32.BitBlt(mem, 0, 0, w, h, hdc, 0, 0, 0x00CC0020)
    gdi32.SelectObject(mem, old)
    local dest = nil
    if gdiplus then
      local image = ffi.new('void*[1]')
      if gdiplus.GdipCreateBitmapFromHBITMAP(bmp, nil, image) == 0 and image[0] ~= nil then
        dest = getWorkingDirectory() .. '\\referenz_up.jpg'
        local status = gdiplus.GdipSaveImageToFile(image[0], wide(dest), jpegClsid, nil)
        gdiplus.GdipDisposeImage(image[0])
        if status ~= 0 then dest = nil end
      end
    end
    gdi32.DeleteObject(bmp)
    gdi32.DeleteDC(mem)
    user32.ReleaseDC(hwnd, hdc)
    return dest
  end)
  if ok and path then return path, '.jpg' end
  return nil, '.jpg'
end

function unescapeUrl(s)
  return tostring(s or ''):gsub('\\/', '/')
end

function pickUrl(resp)
  resp = tostring(resp or '')
  local url = resp:match('"direct_url"%s*:%s*"(.-)"')
    or resp:match('"display_url"%s*:%s*"(.-)"')
    or resp:match('"shareUrl"%s*:%s*"(.-)"')
    or resp:match('"album_url"%s*:%s*"(.-)"')
    or resp:match('"url"%s*:%s*"(https?://[^"]+)"')
  url = unescapeUrl(url)
  if url:find('ibb.co', 1, true) or url:find('imgbb', 1, true) then
    return url
  end
  if url:find('^https?://') and resp:match('"host"%s*:%s*"(%w+)"') then
    return url
  end
  return nil
end

function imgbbFile()
  return getWorkingDirectory() .. '\\referenz-imgbb.txt'
end

function readImgbbShots()
  local list = {}
  local f = io.open(imgbbFile(), 'rb')
  if not f then return list end
  local text = f:read('*a') or ''
  f:close()
  for line in text:gmatch('[^\r\n]+') do
    local id, viewer, direct = line:match('^([^\t]+)\t([^\t]+)\t([^\t]+)')
    if id and direct and direct ~= '' then
      list[#list + 1] = {
        id = id,
        url = direct,
        link = direct,
        viewer = viewer,
        pub = true,
      }
    end
    if #list >= 40 then break end
  end
  return list
end

function rememberImgbb(resp)
  resp = tostring(resp or '')
  local direct = unescapeUrl(resp:match('"display_url"%s*:%s*"(https?://[^"]+)"') or '')
  if direct == '' then
    direct = unescapeUrl(resp:match('"url"%s*:%s*"(https?://i%.ibb%.co[^"]+)"') or '')
  end
  if direct == '' then direct = pickUrl(resp) or '' end
  if direct == '' then return end
  local viewer = unescapeUrl(resp:match('"url_viewer"%s*:%s*"(https?://[^"]+)"') or '')
  if viewer == '' then viewer = direct end
  local id = resp:match('"id"%s*:%s*"([^"]+)"') or direct:match('/([^/%?]+)%.%w+$') or tostring(os.time())
  id = id:gsub('[^%w%-_]', '')
  if id == '' then return end
  local rows = { id .. '\t' .. viewer .. '\t' .. direct }
  local seen = { [id] = true }
  local f = io.open(imgbbFile(), 'rb')
  if f then
    local text = f:read('*a') or ''
    f:close()
    for line in text:gmatch('[^\r\n]+') do
      local old = line:match('^([^\t]+)')
      if old and not seen[old] then
        rows[#rows + 1] = line
        seen[old] = true
      end
      if #rows >= 40 then break end
    end
  end
  local out = io.open(imgbbFile(), 'wb')
  if not out then return end
  out:write(table.concat(rows, '\n'))
  out:close()
  if useImgbb() then hub.shots = readImgbbShots() end
end

function copyUrl(url)
  hubClip(url)
end

function handleUploadResp(resp, err)
  if not resp then
    chat('Нет связи с сайтом' .. (err and (' (' .. err .. ')') or ''))
    return false
  end
  local errorText = resp:match('"error"%s*:%s*"(.-)"')
  if not errorText then
    errorText = resp:match('"message"%s*:%s*"(.-)"')
    if errorText and not resp:match('"success"%s*:%s*true') then
      -- keep
    else
      errorText = nil
    end
  end
  if errorText then
    chat(errorText)
    return false
  end
  local url = pickUrl(resp)
  if url and url ~= '' then
    if url:find('ibb.co', 1, true) or url:find('imgbb', 1, true) then
      rememberImgbb(resp)
    end
    copyUrl(url)
    chat(url)
    return true
  end
  local id = resp:match('"id"%s*:%s*"(%w+)"')
  if not id then
    chat('Не удалось загрузить')
    return false
  end
  chat('Скрин во входящих')
  return true
end

local ok_effil, effil = pcall(require, 'effil')
if not ok_effil then effil = nil end

function startBgUpload(url, token, path, filename)
  if not effil then return nil end
  return effil.thread(function(url, token, path, filename)
    local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function b64encode(data)
      local out = {}
      for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0
        c = c or 0
        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1
        if not data:byte(i + 1) then
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. '=='
        elseif not data:byte(i + 2) then
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. '='
        else
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. B64:sub(c4, c4)
        end
      end
      return table.concat(out)
    end
    local f = io.open(path, 'rb')
    if not f then return false, 'no file' end
    local data = f:read('*a')
    f:close()
    if not data or #data < 1000 then return false, 'empty' end
    local mime = 'image/png'
    if filename:sub(-4) == '.jpg' then mime = 'image/jpeg' end
    if filename:sub(-4) == '.bmp' then mime = 'image/bmp' end
    local body = '{"image":"' .. b64encode(data) .. '","filename":"' .. filename .. '","mime":"' .. mime .. '","source":"samp"}'
    local ok_req, requests = pcall(require, 'requests')
    if not ok_req or not requests then return false, 'no requests' end
    local ok, resp = pcall(requests.post, url, {
      data = body,
      headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. token,
      },
      timeout = 60
    })
    if not ok then return false, tostring(resp) end
    if resp and resp.text then return true, resp.text end
    return false, 'empty resp'
  end)(url, token, path, filename)
end

function startImgbbUpload(key, path, filename)
  if not effil then return nil end
  return effil.thread(function(key, path, filename)
    local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local function b64encode(data)
      local out = {}
      for i = 1, #data, 3 do
        local a, b, c = data:byte(i, i + 2)
        b = b or 0
        c = c or 0
        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64 + 1
        local c2 = math.floor(n / 4096) % 64 + 1
        local c3 = math.floor(n / 64) % 64 + 1
        local c4 = n % 64 + 1
        if not data:byte(i + 1) then
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. '=='
        elseif not data:byte(i + 2) then
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. '='
        else
          out[#out + 1] = B64:sub(c1, c1) .. B64:sub(c2, c2) .. B64:sub(c3, c3) .. B64:sub(c4, c4)
        end
      end
      return table.concat(out)
    end
    local function enc(s)
      return (tostring(s or ''):gsub('([^%w%-_%.~])', function(c)
        return string.format('%%%02X', string.byte(c))
      end))
    end
    local f = io.open(path, 'rb')
    if not f then return false, 'no file' end
    local data = f:read('*a')
    f:close()
    if not data or #data < 1000 then return false, 'empty' end
    local body = 'key=' .. enc(key) .. '&image=' .. enc(b64encode(data)) .. '&name=' .. enc(filename)
    local ok_req, requests = pcall(require, 'requests')
    if not ok_req or not requests then return false, 'no requests' end
    local ok, resp = pcall(requests.post, 'https://api.imgbb.com/1/upload', {
      data = body,
      headers = {
        ['Content-Type'] = 'application/x-www-form-urlencoded',
      },
      timeout = 60
    })
    if not ok then return false, tostring(resp) end
    if resp and resp.text then return true, resp.text end
    return false, 'empty resp'
  end)(key, path, filename)
end

function waitRemote(runner, path, failMsg)
  if not runner then
    chat('Не удалось загрузить')
    pcall(os.remove, path)
    return
  end
  local t0 = os.clock()
  while os.clock() - t0 < 90 do
    local status, err = runner:status()
    if err then
      chat(failMsg)
      pcall(os.remove, path)
      return
    end
    if status == 'completed' then
      local ok, text = runner:get()
      if ok then
        handleUploadResp(text)
      else
        handleUploadResp(nil, text)
      end
      pcall(os.remove, path)
      return
    elseif status == 'canceled' then
      chat('Не удалось загрузить')
      pcall(os.remove, path)
      return
    end
    wait(0)
  end
  chat(failMsg)
  pcall(os.remove, path)
end

function queueUpload(path, ext)
  if not path then return end
  if useImgbb() then
    local key = imgbbKey()
    if key == '' then
      chat('Укажите ключ ImgBB в /referenz')
      openLoginWindow()
      pcall(os.remove, path)
      return
    end
    local filename = 'samp-' .. tostring(os.time()) .. (ext or '.jpg')
    chat('Загружаю на ImgBB...')
    waitRemote(startImgbbUpload(key, path, filename), path, 'ImgBB не ответил')
    return
  end
  if not loggedIn() then
    if cfg.referenz.username ~= '' and cfg.referenz.password ~= '' then
      doAuth('login', cfg.referenz.username, cfg.referenz.password, true)
    end
  end
  if not loggedIn() then
    openLoginWindow()
    pcall(os.remove, path)
    return
  end
  local filename = 'samp-' .. tostring(os.time()) .. (ext or '.jpg')
  chat('Загружаю...')
  local token = cfg.referenz.token
  local url = SITE .. '/api/photos'
  local runner = startBgUpload(url, token, path, filename)
  if runner then
    local t0 = os.clock()
    while os.clock() - t0 < 90 do
      local status, err = runner:status()
      if err then
        chat('Нет связи с сайтом')
        pcall(os.remove, path)
        return
      end
      if status == 'completed' then
        local ok, text = runner:get()
        if ok then
          if tostring(text):match('Нужно войти') and cfg.referenz.username ~= '' then
            doAuth('login', cfg.referenz.username, cfg.referenz.password, true)
            runner = startBgUpload(url, cfg.referenz.token, path, filename)
            t0 = os.clock()
          else
            handleUploadResp(text)
            pcall(os.remove, path)
            return
          end
        else
          handleUploadResp(nil, text)
          pcall(os.remove, path)
          return
        end
      elseif status == 'canceled' then
        chat('Не удалось загрузить')
        pcall(os.remove, path)
        return
      end
      wait(0)
    end
    chat('Нет связи с сайтом')
    pcall(os.remove, path)
    return
  end
  chat('Не удалось загрузить')
  pcall(os.remove, path)
end

function startUpload(src)
  if busy or not src then return end
  if useImgbb() then
    if imgbbKey() == '' then
      chat('Укажите ключ ImgBB в /referenz')
      openLoginWindow()
      return
    end
  elseif not loggedIn() then
    if cfg.referenz.username ~= '' and cfg.referenz.password ~= '' then
      doAuth('login', cfg.referenz.username, cfg.referenz.password, true)
    end
    if not loggedIn() then
      openLoginWindow()
      return
    end
  end
  busy = true
  local tmp, ext = src, (src:match('(%.[^\\/%.]+)$') or '.jpg')
  if not tostring(src):find('referenz_up', 1, true) then
    tmp, ext = copyShot(src)
  end
  busy = false
  if not tmp then
    chat('Не удалось прочитать скрин')
    return
  end
  queueUpload(tmp, ext)
end

function onD3DPresent()
  if ui.ready == 'imgui' then
    old_imgui.Process = ui.showClassic
  end
end

function onWindowMessage(msg, wparam)
  if tonumber(wparam) ~= VK_F8 then return end
  if msg ~= WM_KEYDOWN then return end
  if windowOpen() then
    needClose = true
    return
  end
  if not f8Wait then
    f8Clock = os.clock()
    f8Wait = true
  end
end

function onDialogResponse(dialogId, button, list, input)
  if dialogId ~= DLG_USER and dialogId ~= DLG_PASS then return end
  if button ~= 1 then
    authPending.mode = ''
    return
  end
  input = tostring(input or ''):gsub('^%s+', ''):gsub('%s+$', '')
  if dialogId == DLG_USER then
    if input == '' then
      chat('Логин пустой')
      return
    end
    authPending.user = input
    sampShowDialog(DLG_PASS, 3, ru('Вход referenz.pics'), ru('Введите пароль'), ru('Готово'), ru('Отмена'))
    return
  end
  lua_thread.create(function()
    doAuth('login', authPending.user, input)
    authPending.mode = ''
  end)
end

updateBusy = false
local UPDATE_JSON = 'https://raw.githubusercontent.com/andergr0ynd/referenz.pics/refs/heads/main/version.json'
local UPDATE_LUA = 'https://raw.githubusercontent.com/andergr0ynd/referenz.pics/refs/heads/main/referenz.pics.lua'

function updateIsHtml(s)
  s = tostring(s or ''):gsub('^%s+', ''):sub(1, 96):lower()
  return s:sub(1, 9) == '<!doctype' or s:sub(1, 5) == '<html'
end

function updateFetch(urls, minLen)
  for i = 1, #urls do
    local body = httpGet(urls[i] .. ((urls[i]:find('?', 1, true) and '&' or '?') .. 't=' .. tostring(os.time())))
    body = tostring(body or '')
    if body ~= '' and #body >= (minLen or 8) and not updateIsHtml(body) then
      return body
    end
  end
  return nil
end

function updateWriteFile(latest, body)
  if type(body) ~= 'string' or #body < 4000
    or not body:find('script_name', 1, true) or not body:find('function main', 1, true) then
    chat('Обновление прошло неудачно. Запускаю текущую версию.')
    return false
  end
  local path = thisScript().path
  if type(path) ~= 'string' or path == '' then
    chat('Нет пути скрипта')
    return false
  end
  pcall(function()
    local old = io.open(path, 'rb')
    if old then
      local prev = old:read('*a')
      old:close()
      local b = io.open(path .. '.bak', 'wb')
      if b then
        b:write(prev)
        b:close()
      end
    end
  end)
  local f = io.open(path, 'wb')
  if not f then
    chat('Не записалось обновление')
    return false
  end
  f:write(body)
  f:close()
  chat(('Файл обновлён до %s.'):format(latest))
  chat('Перезагрузи скрипт: Ctrl+R или /reload.')
  chat('Не жми обновление повторно, пока не сделаешь Ctrl+R.')
  return true
end

function checkUpdate(manual)
  if updateBusy then
    if manual then chat('Обновление уже идёт') end
    return
  end
  updateBusy = true
  if manual then chat('Проверяю GitHub…') end
  lua_thread.create(function()
    local raw = updateFetch({
      UPDATE_JSON,
      'https://cdn.jsdelivr.net/gh/andergr0ynd/referenz.pics@main/version.json',
    }, 8)
    if type(raw) ~= 'string' then
      updateBusy = false
      if manual then chat('GitHub недоступен') end
      return
    end
    local latest = raw:match('"latest"%s*:%s*"([^"]+)"')
    local updateurl = raw:match('"updateurl"%s*:%s*"([^"]+)"')
    if not latest or latest == '' then
      updateBusy = false
      if manual then chat('Не прочитался version.json') end
      return
    end
    local cur = tostring(thisScript().version or '0')
    if latest == cur then
      updateBusy = false
      if manual then chat(('Уже актуальная версия %s'):format(cur)) end
      return
    end
    if not updateurl or updateurl == '' or not updateurl:find('^https?://') then
      updateurl = UPDATE_LUA
    end
    chat(('Есть обновление: %s -> %s'):format(cur, latest))
    local body = updateFetch({
      updateurl,
      UPDATE_LUA,
      'https://cdn.jsdelivr.net/gh/andergr0ynd/referenz.pics@main/referenz.pics.lua',
    }, 4000)
    if type(body) ~= 'string' then
      updateBusy = false
      chat('Не скачался новый скрипт')
      return
    end
    updateWriteFile(latest, body)
    updateBusy = false
  end)
end

function startAutoUpdate()
  if tostring(cfg.referenz.autoUpdate or '1') == '0' then return end
  lua_thread.create(function()
    local t0 = os.clock()
    while os.clock() - t0 < 45 do wait(500) end
    for _ = 1, 60 do
      local spawned = false
      pcall(function()
        spawned = sampIsLocalPlayerSpawned and sampIsLocalPlayerSpawned()
      end)
      if spawned then break end
      wait(1000)
    end
    wait(2000)
    if not updateBusy then checkUpdate(false) end
  end)
end

function cmdReferenz(args)
  args = args or ''
  local cmd = (args:match('^(%S+)') or ''):lower()
  if cmd == 'logout' then
    doLogout()
    openLoginWindow()
  elseif cmd == 'update' or cmd == 'upd' then
    checkUpdate(true)
  elseif loggedIn() or (useImgbb() and imgbbKey() ~= '') then
    openReferenzHub()
  else
    openLoginWindow()
  end
end

function onScriptTerminate(script)
  if script ~= thisScript() then return end
  cefOpen = false
  killBrowseHelper()
end

function startQuietLogin()
  if loginJob or not effilLib then return end
  local user = tostring(cfg.referenz.username or '')
  local pass = tostring(cfg.referenz.password or '')
  if user == '' or pass == '' then return end
  local payload = '{"username":"' .. jsonEscape(user) .. '","password":"' .. jsonEscape(pass) .. '"}'
  local url = SITE .. '/api/login'
  local ok, th = pcall(function()
    return effilLib.thread(function(loginUrl, body)
      local okReq, requests = pcall(require, 'requests')
      if not okReq or not requests then return '' end
      local okHttp, resp = pcall(requests.post, loginUrl, {
        data = body,
        headers = { ['Content-Type'] = 'application/json' },
        timeout = 20,
      })
      if not okHttp or not resp or type(resp.text) ~= 'string' then return '' end
      return resp.text
    end)(url, payload)
  end)
  if ok and th then
    loginJob = { th = th, user = user, pass = pass, gen = hub.loginGen or 0 }
  end
end

function pollQuietLogin()
  local job = loginJob
  if not job then return end
  local status
  local okStatus = pcall(function() status = job.th:status() end)
  if not okStatus or status == nil or status == 'running' or status == 'paused' then return end
  loginJob = nil
  if job.gen ~= (hub.loginGen or 0) then return end
  if status ~= 'completed' then return end
  local ok, text = pcall(function() return job.th:get() end)
  if ok then finishAuth(text, 'login', job.user, job.pass, true) end
end

function main()
  while not isSampAvailable() do wait(200) end
  pcall(function()
    local dir = thisScript().path:match('^(.*)[/\\][^/\\]+$')
    if dir and dir ~= '' then
      package.path = dir .. '\\?.lua;' .. package.path
    end
  end)
  sampRegisterChatCommand('referenz', cmdReferenz)
  sampRegisterChatCommand('pics', cmdReferenz)
  sampRegisterChatCommand('refupdate', function()
    checkUpdate(true)
  end)
  pcall(fillAuthFields)
  if cfg.referenz.username ~= '' and cfg.referenz.password ~= '' then
    startQuietLogin()
  end
  startAutoUpdate()
  while true do
    if cefOpen or az.status == 'setup' or az.status == 'starting' or az.status == 'ready' or az.pending then
      pumpBrowse()
    end
    if sizeApply then
      sizeApply = false
      commitBrowserSize()
    end
    if wantCefClose then
      wantCefClose = false
      closeReferenzCef()
    end
    pumpThumbs()
    pumpLogo()
    wait(0)
    flushClip()
    pollQuietLogin()
    if dropHub then
      dropHub = false
      closeReferenzCef()
      if ui.hub then ui.hub[0] = false end
      if hub.openLogin then
        hub.openLogin = false
        openLoginWindow()
      else
        mouseHold = false
      end
    elseif hubWant then
      hubWant = false
      openReferenzHub()
    elseif needClose then
      needClose = false
      pcall(closeWindow)
      chat('Закройте окно и нажмите F8 ещё раз')
    elseif f8Wait then
      f8Wait = false
      lua_thread.create(function()
        local path = takeGdiShot()
        if not path then
          chat('Не удалось снять кадр')
          return
        end
        startUpload(path)
      end)
    else
      takeThumb()
    end
  end
end
