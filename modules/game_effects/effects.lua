local STACK_GHOST = 255

local LEGACY_EFFECT_SHADERS = {
    [1] = "outfit_white",
    [4] = "outfit_green",
    [5] = "outfit_gray",
    [6] = "outfit_blue"
}

local function getShaderName(var)
    if type(var) ~= 'string' or var == '' then
        return nil
    end

    local shaderName = var:match('^([^|]+)')
    if not shaderName or shaderName == '' then
        return nil
    end

    return shaderName
end

local function onCreatureEffect(creature, effectId, var)
    if not creature:getPosition() then
        return
    end

    local shaderName = getShaderName(var)
    if shaderName then
        creature:setOutfitShader(shaderName)
        return true
    end

    local legacyShader = LEGACY_EFFECT_SHADERS[effectId]
    if legacyShader then
        creature:setOutfitShader(legacyShader)
        return true
    end
end

function onInit()
    connect(Creature, {
        onEffect = onCreatureEffect
    })
end

function onTerminate()
    disconnect(Creature, {
        onEffect = onCreatureEffect
    })
end