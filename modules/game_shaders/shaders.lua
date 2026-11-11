local OUTFIT_SHADERS = {
  { name = "outfit_azulciano", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_azulciano" },
  { name = "outfit_azulmaritimo", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_azulmaritimo" },
  { name = "outfit_blue", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_blue" },
  { name = "outfit_branco", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_branco" },
  { name = "outfit_ciano", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_ciano" },
  { name = "outfit_colorida", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_colorida" },
  { name = "outfit_colorida1", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_colorida1" },
  { name = "outfit_diferentao", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_diferentao" },
  { name = "outfit_gray", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_gray" },
  { name = "outfit_green", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_green" },
  { name = "outfit_laranja", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_laranja" },
  { name = "outfit_marrom", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_marrom" },
  { name = "outfit_outline", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_outline_fragment" },
  { name = "outfit_outline_gold", vertex = "/shaders/outfit_outline_gold_vertex", fragment = "/shaders/outfit_outline_gold_fragment" },
  { name = "outfit_aura_solar", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_aura_solar" },
  { name = "outfit_pink", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_pink" },
  { name = "outfit_preto", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_preto" },
  { name = "outfit_purple", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_purple" },
  { name = "outfit_rainbow2.0", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_rainbow2.0" },
  { name = "outfit_rosa", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_rosa" },
  { name = "outfit_roxo", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_roxo" },
  { name = "outfit_white", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_white" },
  { name = "outfit_yellow", vertex = "/shaders/outfit_outline_vertex", fragment = "/shaders/outfit_yellow" }
}

function init()
  for _, shader in ipairs(OUTFIT_SHADERS) do
    g_shaders.createOutfitShader(shader.name, shader.vertex, shader.fragment)
  end
end

function terminate()
end

