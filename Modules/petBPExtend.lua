local bit32 = require 'bit'
local bnot = bit32.bnot
local bxor = bit32.bxor
local band = bit32.band
local bor = bit32.bor
local rshift = bit32.rshift
local lshift = bit32.lshift

if Pet.Hooked ~= true then
  Pet.Hooked = true;
  ffi.hook.inlineHook("int (__cdecl *)(uint32_t, uint32_t)", function(petPtr, enemyPtr)
    --printAsHex(petPtr);
    local petIndex = ffi.readMemoryInt32(petPtr + 4);
    local enableExt = false;
    local bp = {};
    for i = 1, 5 do
      local k = Pet.FullArtRank(ffi.readMemoryInt32(enemyPtr + 4), i);
      --print('k', i, k);
      bp[i] = k;
      if k > 63 then
        enableExt = true;
      end
    end
    if enableExt then
      local actualBp = {};
      ffi.setMemoryDWORD(petPtr, 1);
      --local allocPoint = ffi.readMemoryDWORD(petPtr + 0xC0);
      for i = 1, 5 do
        local n = Pet.GetArtRank(ffi.readMemoryInt32(enemyPtr + 4), i);
        actualBp[i] = n;
        --print('actual', i, n, bp[i]);
        if bp[i] > 63 then
          local r = math.fmod(bp[i], 64);
          --print('r', r);
          if n > r then
            if (64 + r) - n <= 5 then
              actualBp[i] = bp[i] + (n - (64 + r))
            else
              actualBp[i] = bp[i] + n
            end
          else
            actualBp[i] = bp[i] + n
          end
        end
        --print('actual 2', i, actualBp[i]);
      end
      ---@type PetExt
      local petExt = getModule('petExt');
      local petData = petExt:getData(petIndex);
      petData.PetBPExtend = petData.PetBPExtend or {};
      for i = 1, 5 do
        petData.PetBPExtend[tostring(i)] = actualBp[i];
      end
      petExt:setData(petIndex, petData);
      ffi.setMemoryDWORD(petPtr, 0);
    end
    return 0;
  end, 0x004664AB, 6, {
    0x8B, 0x86, 0xC0, 0x00, 0x00, 0x00,
    0x89, 0x83, 0xC0, 0x00, 0x00, 0x00,
    0x60, --pushad
    0x9C, --pushfd
    0x56, --push ebx
    0x53, --push ebx
  }, {
    0x58, --pop eax 
    0x58, --pop eax 
    0x9D, --popfd
    0x61, --popad
  }, { ignoreOriginCode = true })

  ffi.patch(0x004664B7, { 0x90, 0x90, 0x90, 0x90, 0x90, 0x90 })

  ffi.hook.inlineHook('int (__cdecl *)(uint32_t, uint32_t)', function(ebp, petPtr)
    local petIndex = ffi.readMemoryInt32(petPtr + 4);
    ffi.setMemoryDWORD(ebp - 0xbc, Pet.GetArtRank(petIndex, 1));
    ffi.setMemoryDWORD(ebp - 0xbc - 4, Pet.GetArtRank(petIndex, 2));
    ffi.setMemoryDWORD(ebp - 0xbc - 8, Pet.GetArtRank(petIndex, 3));
    ffi.setMemoryDWORD(ebp - 0xbc - 12, Pet.GetArtRank(petIndex, 4));
    ffi.setMemoryDWORD(ebp - 0xbc - 16, Pet.GetArtRank(petIndex, 5));
    return 0;
  end,
    0x00590D84, 0x00590DC5 - 0x00590D84,
    {
      0x60, --pushad
      0x9C, --pushfd
      0x56, --push esi
      0x55, --push ebp
    },
    {
      0x58, --pop eax 
      0x58, --pop eax 
      0x9D, --popfd
      0x61, --popad
    },
    { ignoreOriginCode = true }
  );
  ffi.hook.inlineHook('int (__cdecl *)(uint32_t, uint32_t)', function(ebp, petPtr)
    local petIndex = ffi.readMemoryInt32(petPtr + 4);
    --print('lvup', ffi.readMemoryFloat(ebp - 0x6c), Pet.GetArtRank(petIndex, 1));
    ffi.setMemoryFloat(ebp - 0x6c, Pet.GetArtRank(petIndex, 1) * 1.0);
    ffi.setMemoryFloat(ebp - 0x6c - 4, Pet.GetArtRank(petIndex, 2) * 1.0);
    ffi.setMemoryFloat(ebp - 0x6c - 8, Pet.GetArtRank(petIndex, 3) * 1.0);
    ffi.setMemoryFloat(ebp - 0x6c - 12, Pet.GetArtRank(petIndex, 4) * 1.0);
    ffi.setMemoryFloat(ebp - 0x6c - 16, Pet.GetArtRank(petIndex, 5) * 1.0);
    return 0;
  end,
    0x0043A794, 0x0043A7E2 - 0x0043A794,
    {
      0x60, --pushad
      0x9C, --pushfd
      0x53, --push ebx
      0x55, --push ebp
    },
    {
      0x58, --pop eax 
      0x58, --pop eax 
      0x9D, --popfd
      0x61, --popad
    },
    { ignoreOriginCode = true }
  );

  Pet._SetArtRank = Pet.SetArtRank;
  Pet.SetArtRank = function(petIndex, artType, value)
    if petIndex <= 0 then
      return -1;
    end
    if artType < 1 or artType > 5 then
      return -2;
    end
    if value < 0 then
      return -3;
    end
    ---@type PetExt
    local petExt = getModule('petExt');
    local petData = petExt:getData(petIndex);
    if value > 63 or petData.PetBPExtend then
      petData.PetBPExtend[tostring(artType - 1)] = value;
      return 0;
    end
    return Pet._SetArtRank(petIndex, artType, value);
  end

  Pet._GetArtRank = Pet.GetArtRank;
  Pet.GetArtRank = function(petIndex, artType)
    if petIndex <= 0 then
      return -1;
    end
    if artType < 1 or artType > 5 then
      return -2;
    end
    ---@type PetExt
    local petExt = getModule('petExt');
    local petData = petExt:getData(petIndex);
    if petData.PetBPExtend and petData.PetBPExtend[tostring(artType)] ~= nil then
      return tonumber(petData.PetBPExtend[tostring(artType)]);
    end
    return Pet._GetArtRank(petIndex, artType);
  end

  Pet.ArtRank = Pet.GetArtRank
end

---模块类
local PetBPExtend = ModuleBase:createModule('petBPExtend')

--- 加载模块钩子
function PetBPExtend:onLoad()
  self:logInfo('load')
end

--- 卸载模块钩子
function PetBPExtend:onUnload()
  self:logInfo('unload')
end

return PetBPExtend;
