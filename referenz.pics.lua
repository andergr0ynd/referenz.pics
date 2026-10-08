-- referenz.pics: вход в аккаунт и F8 на сайт.
-- Скопировать в moonloader/referenz.pics.lua и нажать Ctrl+R.
-- /referenz — окно входа

script_name('referenz.pics')
script_author('referenz.pics')
script_version('2.17')

local ffi = require 'ffi'
local inicfg = require 'inicfg'

local encoding_ok, encoding = pcall(require, 'encoding')
if encoding_ok then
  encoding.default = 'CP1251'
end

local function ru(text)
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

local function chat(text)
  pcall(function()
    if sampAddChatMessage then
      sampAddChatMessage(ru('[referenz.pics] ' .. tostring(text or '')), 0xFFE4C15A)
    end
  end)
end

local function wide(str)
  str = tostring(str or '')
  local n = #str
  local buf = ffi.new('unsigned short[?]', n + 1)
  for i = 1, n do
    buf[i - 1] = str:byte(i)
  end
  buf[n] = 0
  return buf
end

local function lastErr()
  return tonumber(kernel32.GetLastError()) or 0
end

local function parseUrl(url)
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

local function httpWinHttp(method, scheme, host, port, path, headers, body)
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
  while winhttp.WinHttpReadData(hReq, buf, 8191, read) ~= 0 and read[0] > 0 do
    chunks[#chunks + 1] = ffi.string(buf, read[0])
  end
  winhttp.WinHttpCloseHandle(hReq)
  winhttp.WinHttpCloseHandle(hConn)
  winhttp.WinHttpCloseHandle(hOpen)
  return table.concat(chunks)
end

local function httpWininet(method, scheme, host, port, path, headers, body)
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

local function httpPost(url, headers, body)
  local scheme, host, port, path = parseUrl(url)
  if not host then return nil, 'bad url' end
  local resp, err = httpWinHttp('POST', scheme, host, port, path, headers, body)
  if resp and resp ~= '' then return resp end
  return httpWininet('POST', scheme, host, port, path, headers, body)
end

local function jsonEscape(s)
  s = tostring(s or '')
  s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\r', '\\r'):gsub('\n', '\\n')
  return s
end

local function setBuf(buf, str, cap)
  ffi.fill(buf, cap)
  str = tostring(str or '')
  if #str > cap - 1 then str = str:sub(1, cap - 1) end
  ffi.copy(buf, str)
end

local function saveCfg()
  pcall(inicfg.save, cfg, 'referenz')
end

local function loggedIn()
  return cfg.referenz.token and cfg.referenz.token ~= ''
end

local function useImgbb()
  return (cfg.referenz.host or '') == 'imgbb'
end

local function imgbbKey()
  return tostring(cfg.referenz.imgbb or ''):gsub('%s+', '')
end

local function remoteName()
  if useImgbb() then return 'ImgBB' end
  return 'сайт'
end

local function syncSettings()
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

local function setHost(name)
  if name == 'imgbb' then
    cfg.referenz.host = 'imgbb'
  else
    cfg.referenz.host = 'referenz'
  end
  saveCfg()
  syncSettings()
end

local function grabImgbb()
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

local function fillAuthFields()
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

local function readAuthFields()
  if ui.ready == 'mimgui' then
    return ffi.string(ui.user), ffi.string(ui.pass)
  end
  if ui.ready == 'imgui' then
    return ui.userC.v, ui.passC.v
  end
  return '', ''
end

local function closeWindow()
  grabImgbb()
  syncSettings()
  if ui.ready == 'mimgui' then
    ui.show[0] = false
  else
    ui.showClassic = false
  end
end

local function windowOpen()
  if ui.ready == 'mimgui' and ui.show then
    return ui.show[0] and true or false
  end
  return ui.showClassic and true or false
end

local function doAuth(kind, username, password, quiet)
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
  end
  return true
end

local function startAuth(kind)
  local user, pass = readAuthFields()
  lua_thread.create(function()
    doAuth(kind, user, pass)
  end)
end

local function openLoginWindow()
  ui.msg = ''
  fillAuthFields()
  if ui.ready == 'mimgui' then
    ui.show[0] = true
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

local function doLogout()
  cfg.referenz.username = ''
  cfg.referenz.password = ''
  cfg.referenz.token = ''
  saveCfg()
  fillAuthFields()
  ui.msg = ''
  chat('Вы вышли')
end

local WIN_W = 400
local WIN_H = 500

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

local function v4(lib, c)
  return lib.ImVec4(c[1], c[2], c[3], c[4] or 1)
end

local function pushHardStyle(lib)
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

local function popHardStyle(lib, nCol, nVar)
  if nCol > 0 then pcall(lib.PopStyleColor, nCol) end
  if nVar > 0 then pcall(lib.PopStyleVar, nVar) end
end

local function windowFlags(lib)
  local f = 1 + 2 + 32
  pcall(function()
    local W = lib.WindowFlags
    if W then
      f = (W.NoTitleBar or 1) + (W.NoResize or 2) + (W.NoCollapse or 32)
    end
  end)
  return f
end

local function goldBtn(lib, label, w, h)
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

local function drawLoginWindow()
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

    if lib.SetCursorPos then lib.SetCursorPos(lib.ImVec2(22, 16)) end
    if lib.TextColored then
      lib.TextColored(v4(lib, PAL.text), 'referenz')
      lib.SameLine(0, 0)
      lib.TextColored(v4(lib, PAL.gold), '.pics')
    else
      lib.Text('referenz.pics')
    end
    if lib.SameLine then lib.SameLine(WIN_W - 50) end
    if lib.SetCursorPosY then lib.SetCursorPosY(12) end
    if lib.PushStyleColor and lib.Col then
      pcall(lib.PushStyleColor, lib.Col.Button, lib.ImVec4(0.80, 0.22, 0.32, 0.45))
      pcall(lib.PushStyleColor, lib.Col.ButtonHovered, lib.ImVec4(0.90, 0.25, 0.35, 0.75))
    end
    if lib.Button('X', lib.ImVec2(28, 28)) then closeWindow() end
    pcall(lib.PopStyleColor, 2)

    if lib.SetCursorPos then lib.SetCursorPos(lib.ImVec2(22, 58)) end
    if lib.BeginChild then
      lib.BeginChild('##body', lib.ImVec2(WIN_W - 36, WIN_H - 72), false)
    end

    lib.TextDisabled('куда грузить F8')
    do
      local bw = 168
      local cur = cfg.referenz.host or 'referenz'
      local function hostBtn(id, label)
        if cur == id then
          goldBtn(lib, label, bw, 28)
        elseif lib.Button(label, lib.ImVec2(bw, 28)) then
          grabImgbb()
          setHost(id)
        end
      end
      hostBtn('referenz', 'сайт')
      if lib.SameLine then lib.SameLine(0, 6) end
      hostBtn('imgbb', 'ImgBB')
    end
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

    if lib.EndChild then lib.EndChild() end
  end
  lib.End()
  popHardStyle(lib, nCol, nVar)
end

if ui.ready == 'mimgui' then
  imgui.OnInitialize(function()
    imgui.GetIO().IniFilename = nil
  end)
  imgui.OnFrame(function()
    return ui.show[0]
  end, function(player)
    if player then
      player.HideCursor = false
    end
    pcall(drawLoginWindow)
  end)
end

if ui.ready == 'imgui' then
  function old_imgui.OnDrawFrame()
    if ui.showClassic then
      drawLoginWindow()
    end
  end
end

local function ftNum(ft)
  return tonumber(ft.dwHighDateTime) * 4294967296 + tonumber(ft.dwLowDateTime)
end

local function nowStamp()
  local ft = ffi.new('FILETIME')
  kernel32.GetSystemTimeAsFileTime(ft)
  return ftNum(ft)
end

local function isShotName(name)
  name = tostring(name or ''):lower()
  if name == '' or name == '.' or name == '..' then return false end
  if name == 'sampgui.png' or name:find('sampgui') then return false end
  return name:find('%.png$') or name:find('%.jpe?g$') or name:find('%.bmp$')
end

local function screenRoots()
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

local function listDir(dir, files, depth)
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

local function indexShots()
  local files = {}
  pcall(function()
    for _, dir in ipairs(screenRoots()) do
      listDir(dir, files, 0)
    end
  end)
  return files
end

local function findChanged(before)
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

local function copyShot(src)
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

local function u32le(n)
  n = math.floor(tonumber(n) or 0) % 4294967296
  local b1 = n % 256
  n = math.floor(n / 256)
  local b2 = n % 256
  n = math.floor(n / 256)
  local b3 = n % 256
  n = math.floor(n / 256)
  return string.char(b1, b2, b3, n % 256)
end

local function takeGdiShot()
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

local function unescapeUrl(s)
  return tostring(s or ''):gsub('\\/', '/')
end

local function pickUrl(resp)
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

local function copyUrl(url)
  pcall(function()
    if setClipboard then setClipboard(url) end
  end)
end

local function handleUploadResp(resp, err)
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

local function startBgUpload(url, token, path, filename)
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

local function startImgbbUpload(key, path, filename)
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

local function waitRemote(runner, path, failMsg)
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

local function queueUpload(path, ext)
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

local function startUpload(src)
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

function cmdReferenz(args)
  args = args or ''
  local cmd = (args:match('^(%S+)') or ''):lower()
  if cmd == 'logout' then
    doLogout()
    openLoginWindow()
  else
    openLoginWindow()
  end
end

function main()
  while not isSampAvailable() do wait(200) end
  sampRegisterChatCommand('referenz', cmdReferenz)
  sampRegisterChatCommand('pics', cmdReferenz)
  pcall(fillAuthFields)
  if cfg.referenz.username ~= '' and cfg.referenz.password ~= '' then
    lua_thread.create(function()
      wait(500)
      doAuth('login', cfg.referenz.username, cfg.referenz.password, true)
    end)
  end
  while true do
    wait(0)
    if needClose then
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
    end
  end
end
