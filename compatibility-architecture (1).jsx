import { useState } from "react";

const COLORS = {
  bg: "#0a0a0f",
  card: "#12121a",
  cardHover: "#1a1a25",
  border: "#1e1e2e",
  accent: "#c084fc",
  accentDim: "#7c3aed",
  accentGlow: "rgba(192, 132, 252, 0.15)",
  red: "#f87171",
  redDim: "rgba(248, 113, 113, 0.15)",
  orange: "#fb923c",
  orangeDim: "rgba(251, 146, 60, 0.15)",
  green: "#4ade80",
  greenDim: "rgba(74, 222, 128, 0.15)",
  blue: "#60a5fa",
  blueDim: "rgba(96, 165, 250, 0.15)",
  yellow: "#facc15",
  yellowDim: "rgba(250, 204, 21, 0.15)",
  pink: "#f472b6",
  pinkDim: "rgba(244, 114, 182, 0.15)",
  cyan: "#22d3ee",
  cyanDim: "rgba(34, 211, 238, 0.15)",
  text: "#e2e8f0",
  textDim: "#94a3b8",
  textMuted: "#64748b",
};

const tabs = [
  { id: "overview", label: "Visão Geral", icon: "◉" },
  { id: "filters", label: "Filtros Eliminatórios", icon: "⊘" },
  { id: "ai", label: "IA Deal Breakers", icon: "⚡" },
  { id: "scoring", label: "Cálculo de Score", icon: "◈" },
  { id: "astro", label: "Astrologia", icon: "✦" },
  { id: "display", label: "Exibição ao Usuário", icon: "◐" },
  { id: "dataflow", label: "Fluxo de Dados", icon: "⟐" },
];

// ─── FLOW NODE COMPONENT ───
function FlowNode({ label, sublabel, color, type = "process", width = "100%" }) {
  const styles = {
    process: { borderRadius: 10, border: `1.5px solid ${color}40`, background: `${color}10` },
    decision: { borderRadius: 10, border: `1.5px dashed ${color}60`, background: `${color}08`, transform: "skewX(-2deg)" },
    terminal: { borderRadius: 20, border: `2px solid ${color}`, background: `${color}18`, boxShadow: `0 0 20px ${color}20` },
    eliminated: { borderRadius: 10, border: `2px solid ${COLORS.red}80`, background: COLORS.redDim },
  };
  return (
    <div style={{ width, padding: "12px 16px", textAlign: "center", ...styles[type], marginBottom: 4 }}>
      <div style={{ fontSize: 13, fontWeight: 600, color: type === "eliminated" ? COLORS.red : color, letterSpacing: "0.02em" }}>{label}</div>
      {sublabel && <div style={{ fontSize: 11, color: COLORS.textDim, marginTop: 4 }}>{sublabel}</div>}
    </div>
  );
}

function Arrow({ color = COLORS.textMuted, label, dashed }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", padding: "2px 0" }}>
      <div style={{ width: 1.5, height: 16, background: color, borderStyle: dashed ? "dashed" : "solid" }} />
      {label && <div style={{ fontSize: 10, color, padding: "2px 8px", background: `${color}10`, borderRadius: 4 }}>{label}</div>}
      <div style={{ width: 0, height: 0, borderLeft: "5px solid transparent", borderRight: "5px solid transparent", borderTop: `6px solid ${color}` }} />
    </div>
  );
}

function SplitArrow({ leftLabel, rightLabel, leftColor, rightColor }) {
  return (
    <div style={{ display: "flex", justifyContent: "center", gap: 40, padding: "4px 0" }}>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ fontSize: 10, color: leftColor, marginBottom: 4 }}>{leftLabel}</div>
        <div style={{ width: 0, height: 0, borderLeft: "5px solid transparent", borderRight: "5px solid transparent", borderTop: `6px solid ${leftColor}` }} />
      </div>
      <div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ fontSize: 10, color: rightColor, marginBottom: 4 }}>{rightLabel}</div>
        <div style={{ width: 0, height: 0, borderLeft: "5px solid transparent", borderRight: "5px solid transparent", borderTop: `6px solid ${rightColor}` }} />
      </div>
    </div>
  );
}

function Badge({ label, color, size = "sm" }) {
  const s = size === "sm" ? { fontSize: 10, padding: "2px 8px" } : { fontSize: 12, padding: "4px 12px" };
  return (
    <span style={{ ...s, background: `${color}18`, color, border: `1px solid ${color}40`, borderRadius: 20, fontWeight: 600, display: "inline-block", margin: 2 }}>
      {label}
    </span>
  );
}

function Section({ title, children, color = COLORS.accent }) {
  return (
    <div style={{ marginBottom: 28 }}>
      <div style={{ fontSize: 15, fontWeight: 700, color, marginBottom: 12, display: "flex", alignItems: "center", gap: 8 }}>
        <div style={{ width: 3, height: 16, background: color, borderRadius: 2 }} />
        {title}
      </div>
      {children}
    </div>
  );
}

function Card({ children, style = {} }) {
  return (
    <div style={{ background: COLORS.card, border: `1px solid ${COLORS.border}`, borderRadius: 12, padding: 20, ...style }}>
      {children}
    </div>
  );
}

function WeightBar({ label, weight, color, detail }) {
  return (
    <div style={{ marginBottom: 14 }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
        <span style={{ fontSize: 12, fontWeight: 600, color }}>{label}</span>
        <span style={{ fontSize: 12, fontWeight: 700, color }}>{weight}%</span>
      </div>
      <div style={{ height: 8, background: COLORS.border, borderRadius: 4, overflow: "hidden" }}>
        <div style={{ height: "100%", width: `${weight}%`, background: `linear-gradient(90deg, ${color}80, ${color})`, borderRadius: 4, transition: "width 0.8s ease" }} />
      </div>
      {detail && <div style={{ fontSize: 11, color: COLORS.textDim, marginTop: 4 }}>{detail}</div>}
    </div>
  );
}

// ─── TAB PANELS ───

function OverviewPanel() {
  return (
    <div>
      <Section title="ARQUITETURA COMPLETA DO SISTEMA DE COMPATIBILIDADE" color={COLORS.accent}>
        <Card>
          <div style={{ fontSize: 13, color: COLORS.textDim, lineHeight: 1.7, marginBottom: 16 }}>
            O sistema opera em <span style={{ color: COLORS.accent, fontWeight: 600 }}>3 fases sequenciais</span>. Cada fase
            é um portão: se o perfil não passa, ele é descartado antes de chegar à próxima. Isso otimiza performance
            (não calcula score de quem seria eliminado) e garante respeito às preferências do usuário.
          </div>

          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
            <FlowNode label="FASE 1 — FILTROS ELIMINATÓRIOS" sublabel="Gênero/Orientação + Deal Breakers absolutos" color={COLORS.red} type="terminal" />
            <Arrow color={COLORS.green} label="PASSOU" />
            <FlowNode label="FASE 2 — PENALIZAÇÕES PESADAS" sublabel="Tipo de relacionamento + Deal Breakers médios" color={COLORS.orange} type="decision" />
            <Arrow color={COLORS.accent} label="SCORE AJUSTADO" />
            <FlowNode label="FASE 3 — CÁLCULO DE SCORE" sublabel="4 blocos ponderados: Amor (35%) + Estilo (25%) + Valores (25%) + Astro (15%)" color={COLORS.accent} type="process" />
            <Arrow color={COLORS.green} label="SCORE FINAL" />
            <FlowNode label="GERAÇÃO DE MOTIVOS (IA)" sublabel="Pontos fortes · Complementaridades · Atenções" color={COLORS.cyan} type="process" />
            <Arrow color={COLORS.blue} />
            <FlowNode label="EXIBIÇÃO AO USUÁRIO" sublabel="Score + Label + 3 blocos explicativos" color={COLORS.green} type="terminal" />
          </div>
        </Card>
      </Section>

      <Section title="GRAFO DE DEPENDÊNCIAS DOS CAMPOS" color={COLORS.blue}>
        <Card>
          <div style={{ fontSize: 11, color: COLORS.textDim, marginBottom: 12 }}>Cada campo do onboarding alimenta um ou mais blocos do cálculo. Campos podem ser compartilhados entre blocos.</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            {[
              { block: "Filtros Eliminatórios", color: COLORS.red, fields: ["genero", "orientacao_sexual", "quer_ver", "deal_breakers (texto livre)"] },
              { block: "Linguagem do Amor (35%)", color: COLORS.pink, fields: ["linguagem_amor", "o_que_atrai"] },
              { block: "Estilo de Vida (25%)", color: COLORS.green, fields: ["fumo", "alcool", "exercicio", "tipo_exercicio", "dieta", "hobbies", "horario_online"] },
              { block: "Valores e Personalidade (25%)", color: COLORS.blue, fields: ["mbti", "visao_politica", "dataria_visao_diferente", "religiao", "qual_religiao", "situacao_atual", "area_expertise", "hobbies"] },
              { block: "Astrologia (15%)", color: COLORS.accent, fields: ["signo_solar", "signo_lunar", "ascendente", "venus", "marte", "mercurio"] },
              { block: "Penalizações", color: COLORS.orange, fields: ["tipo_relacionamento", "estilo_relacionamento", "deal_breakers (JSON processado)"] },
            ].map((b, i) => (
              <div key={i} style={{ padding: 12, background: `${b.color}08`, border: `1px solid ${b.color}25`, borderRadius: 8 }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: b.color, marginBottom: 8 }}>{b.block}</div>
                {b.fields.map((f, j) => (
                  <div key={j} style={{ fontSize: 10, color: COLORS.textDim, padding: "2px 0", borderBottom: j < b.fields.length - 1 ? `1px solid ${COLORS.border}` : "none" }}>
                    <code style={{ color: b.color, fontSize: 10 }}>{f}</code>
                  </div>
                ))}
              </div>
            ))}
          </div>
        </Card>
      </Section>
    </div>
  );
}

function FiltersPanel() {
  return (
    <div>
      <Section title="FILTRO 1 — GÊNERO / ORIENTAÇÃO SEXUAL" color={COLORS.red}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, lineHeight: 1.7, marginBottom: 16 }}>
            Primeiro filtro executado. <span style={{ color: COLORS.red }}>Custo zero de processamento</span> — é uma comparação direta de campos.
            Se não bater, o perfil nunca entra no pipeline de score.
          </div>

          <div style={{ background: COLORS.bg, borderRadius: 8, padding: 16, marginBottom: 16 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.cyan, marginBottom: 10 }}>LÓGICA DE CRUZAMENTO</div>
            <div style={{ fontFamily: "monospace", fontSize: 11, color: COLORS.text, lineHeight: 1.8 }}>
              <div style={{ color: COLORS.textMuted }}>// Para cada par de perfis (A, B):</div>
              <div><span style={{ color: COLORS.accent }}>SE</span> A.quer_ver <span style={{ color: COLORS.yellow }}>inclui</span> B.genero</div>
              <div><span style={{ color: COLORS.accent }}>&& </span> B.quer_ver <span style={{ color: COLORS.yellow }}>inclui</span> A.genero</div>
              <div style={{ color: COLORS.green }}>→ PASSA para próximo filtro</div>
              <br />
              <div><span style={{ color: COLORS.accent }}>SENÃO</span></div>
              <div style={{ color: COLORS.red }}>→ ELIMINADO (perfil nunca aparece)</div>
            </div>
          </div>

          <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.yellow, marginBottom: 8 }}>CASOS ESPECIAIS</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
            {[
              { caso: 'quer_ver = "todos"', resultado: "Aceita qualquer gênero → sempre passa", color: COLORS.green },
              { caso: 'genero = "rather_not_say"', resultado: "Só aparece para quem quer ver 'todos'", color: COLORS.yellow },
              { caso: "Não-binário + Gênero Fluido", resultado: "Mapeados como gênero próprio, não como 'todos'", color: COLORS.blue },
              { caso: "Bidirecional obrigatório", resultado: "Ambos precisam aceitar o gênero do outro", color: COLORS.accent },
            ].map((c, i) => (
              <div key={i} style={{ padding: 10, background: `${c.color}08`, border: `1px solid ${c.color}20`, borderRadius: 8 }}>
                <code style={{ fontSize: 10, color: c.color }}>{c.caso}</code>
                <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 4 }}>{c.resultado}</div>
              </div>
            ))}
          </div>
        </Card>
      </Section>

      <Section title="FILTRO 2 — DEAL BREAKERS ELIMINATÓRIOS" color={COLORS.red}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, lineHeight: 1.7, marginBottom: 16 }}>
            A IA já processou o texto livre e gerou um JSON estruturado. Nesta fase, o sistema lê <span style={{ color: COLORS.red }}>apenas os itens marcados como "eliminatorio: true"</span> e compara com os campos do outro perfil.
          </div>

          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
            <FlowNode label="JSON de Deal Breakers do Usuário A" sublabel='Exemplo: {"fumo": {"eliminatorio": "sim", "penalizacao": "ocasionalmente", "pts": -35}}' color={COLORS.orange} type="process" />
            <Arrow color={COLORS.yellow} label="PARA CADA REGRA" />
            <FlowNode label="Compara com campo correspondente do Usuário B" sublabel="B.fumo === 'sim' ?" color={COLORS.cyan} type="decision" />
            <SplitArrow leftLabel="SIM = MATCH COM REJEIÇÃO" rightLabel="NÃO = SEGUE" leftColor={COLORS.red} rightColor={COLORS.green} />
            <div style={{ display: "flex", gap: 20, width: "100%" }}>
              <FlowNode label="❌ ELIMINADO" sublabel="Perfil B nunca aparece para A" color={COLORS.red} type="eliminated" width="50%" />
              <FlowNode label="✓ Próximo check" sublabel="Verifica penalização média" color={COLORS.green} type="process" width="50%" />
            </div>
          </div>

          <div style={{ marginTop: 16, padding: 12, background: COLORS.redDim, borderRadius: 8, border: `1px solid ${COLORS.red}30` }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.red, marginBottom: 6 }}>⚠ IMPORTANTE: BIDIRECIONALIDADE</div>
            <div style={{ fontSize: 11, color: COLORS.textDim, lineHeight: 1.6 }}>
              O filtro roda <strong style={{ color: COLORS.text }}>duas vezes</strong>: deal breakers de A contra perfil de B,
              E deal breakers de B contra perfil de A. Se qualquer direção eliminar, o par é descartado.
            </div>
          </div>
        </Card>
      </Section>
    </div>
  );
}

function AIPanel() {
  return (
    <div>
      <Section title="PIPELINE DA IA DE DEAL BREAKERS" color={COLORS.cyan}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, lineHeight: 1.7, marginBottom: 16 }}>
            A IA é chamada <span style={{ color: COLORS.cyan, fontWeight: 600 }}>uma única vez no onboarding</span>, quando o
            usuário submete o campo de texto livre de deal breakers. Ela não roda em tempo real no match — apenas o JSON resultante é usado.
          </div>

          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 4, marginBottom: 20 }}>
            <FlowNode label="ENTRADA: Texto livre do usuário" sublabel='"Não aceito fumantes, preciso de alguém que se exercite e não suporto conservadores"' color={COLORS.yellow} type="terminal" />
            <Arrow color={COLORS.cyan} label="ENVIADO PARA IA" />
            <FlowNode label="PROMPT DA IA (System)" sublabel="Recebe o mapa_campos completo + texto do usuário" color={COLORS.cyan} type="process" />
            <Arrow color={COLORS.cyan} label="PROCESSAMENTO" />
            <FlowNode label="IA ANALISA E MAPEIA" sublabel="Identifica campos → classifica severidade → atribui pontos" color={COLORS.accent} type="decision" />
            <Arrow color={COLORS.green} label="OUTPUT" />
            <FlowNode label="JSON ESTRUTURADO" sublabel="Salvo no perfil do usuário junto com o texto original" color={COLORS.green} type="terminal" />
          </div>
        </Card>
      </Section>

      <Section title="PROMPT SYSTEM DA IA (Estrutura)" color={COLORS.accent}>
        <Card>
          <div style={{ background: COLORS.bg, borderRadius: 8, padding: 16, fontFamily: "monospace", fontSize: 11, color: COLORS.text, lineHeight: 1.8, overflowX: "auto" }}>
            <div style={{ color: COLORS.accent, fontWeight: 700 }}>// SYSTEM PROMPT — IA de Deal Breakers</div>
            <br />
            <div style={{ color: COLORS.textMuted }}>Você é um sistema que converte preferências de</div>
            <div style={{ color: COLORS.textMuted }}>relacionamento em regras estruturadas.</div>
            <br />
            <div style={{ color: COLORS.yellow }}>ENTRADA:</div>
            <div style={{ color: COLORS.textDim }}>- Texto livre do usuário com seus deal breakers</div>
            <div style={{ color: COLORS.textDim }}>- Mapa completo de campos do sistema (JSON)</div>
            <br />
            <div style={{ color: COLORS.yellow }}>TAREFA:</div>
            <div style={{ color: COLORS.textDim }}>1. Leia o texto do usuário</div>
            <div style={{ color: COLORS.textDim }}>2. Identifique cada preferência mencionada</div>
            <div style={{ color: COLORS.textDim }}>3. Mapeie para o campo correspondente no sistema</div>
            <div style={{ color: COLORS.textDim }}>4. Classifique cada uma em:</div>
            <div style={{ color: COLORS.red, paddingLeft: 16 }}>• eliminatorio: valor que elimina o perfil</div>
            <div style={{ color: COLORS.orange, paddingLeft: 16 }}>• penalizacao: valor próximo que perde pontos</div>
            <div style={{ color: COLORS.textDim }}>5. Atribua pontos de penalização (-15 a -40)</div>
            <br />
            <div style={{ color: COLORS.yellow }}>REGRAS:</div>
            <div style={{ color: COLORS.textDim }}>- Só use campos que existem no mapa_campos</div>
            <div style={{ color: COLORS.textDim }}>- Só use valores que existem nas opções do campo</div>
            <div style={{ color: COLORS.textDim }}>- Se o texto mencionar algo que não tem campo</div>
            <div style={{ color: COLORS.textDim }}>&nbsp;&nbsp;correspondente, ignore (não invente campos)</div>
            <div style={{ color: COLORS.textDim }}>- Retorne APENAS o JSON, nada mais</div>
            <br />
            <div style={{ color: COLORS.yellow }}>OUTPUT FORMAT:</div>
            <div style={{ color: COLORS.green }}>{"{"}</div>
            <div style={{ color: COLORS.green, paddingLeft: 16 }}>"deal_breakers": {"["}</div>
            <div style={{ color: COLORS.green, paddingLeft: 32 }}>{"{"}</div>
            <div style={{ color: COLORS.green, paddingLeft: 48 }}>"campo": "nome_do_campo",</div>
            <div style={{ color: COLORS.green, paddingLeft: 48 }}>"eliminatorio": "valor_que_elimina",</div>
            <div style={{ color: COLORS.green, paddingLeft: 48 }}>"penalizacao": [{"{"}"valor": "x", "pts": -N{"}"}],</div>
            <div style={{ color: COLORS.green, paddingLeft: 48 }}>"motivo_original": "trecho do texto"</div>
            <div style={{ color: COLORS.green, paddingLeft: 32 }}>{"}"},</div>
            <div style={{ color: COLORS.green, paddingLeft: 32 }}>...</div>
            <div style={{ color: COLORS.green, paddingLeft: 16 }}>{"]"}</div>
            <div style={{ color: COLORS.green }}>{"}"}</div>
          </div>
        </Card>
      </Section>

      <Section title="EXEMPLO COMPLETO DE INPUT → OUTPUT" color={COLORS.green}>
        <Card>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.yellow, marginBottom: 8 }}>INPUT (texto do usuário)</div>
              <div style={{ background: COLORS.bg, borderRadius: 8, padding: 12, fontSize: 11, color: COLORS.text, lineHeight: 1.8, fontStyle: "italic", border: `1px solid ${COLORS.yellow}20` }}>
                "Não aceito fumantes de jeito nenhum. Também preciso de alguém que se exercite regularmente. Conservadores nem pensar, mas se for de centro talvez eu tope. E por favor, sem veganos kk"
              </div>
            </div>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.green, marginBottom: 8 }}>OUTPUT (JSON gerado pela IA)</div>
              <div style={{ background: COLORS.bg, borderRadius: 8, padding: 12, fontSize: 10, color: COLORS.green, lineHeight: 1.6, fontFamily: "monospace", border: `1px solid ${COLORS.green}20` }}>
                {`{
  "deal_breakers": [
    {
      "campo": "fumo",
      "eliminatorio": "sim",
      "penalizacao": [
        {"valor":"ocasionalmente","pts":-35}
      ],
      "motivo": "Não aceito fumantes"
    },
    {
      "campo": "exercicio",
      "eliminatorio": "nao",
      "penalizacao": [],
      "motivo": "preciso que se exercite"
    },
    {
      "campo": "visao_politica",
      "eliminatorio": "conservador",
      "penalizacao": [
        {"valor":"centro","pts":-15}
      ],
      "motivo": "Conservadores nem pensar"
    },
    {
      "campo": "dieta",
      "eliminatorio": "vegano",
      "penalizacao": [
        {"valor":"vegetariano","pts":-20}
      ],
      "motivo": "sem veganos"
    }
  ]
}`}
              </div>
            </div>
          </div>

          <div style={{ marginTop: 16, padding: 12, background: COLORS.cyanDim, borderRadius: 8, border: `1px solid ${COLORS.cyan}30` }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.cyan, marginBottom: 6 }}>💾 ARMAZENAMENTO</div>
            <div style={{ fontSize: 11, color: COLORS.textDim, lineHeight: 1.6 }}>
              No banco de dados do usuário ficam salvos: <code style={{ color: COLORS.cyan }}>deal_breakers_texto</code> (texto original) +
              <code style={{ color: COLORS.cyan }}> deal_breakers_json</code> (JSON processado).
              O texto original é mantido para reprocessamento caso o mapa de campos mude no futuro.
            </div>
          </div>
        </Card>
      </Section>

      <Section title="QUANDO A IA É CHAMADA" color={COLORS.orange}>
        <Card style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 12 }}>
          {[
            { when: "No Onboarding", desc: "Primeira vez que o usuário preenche os deal breakers", color: COLORS.green, icon: "①" },
            { when: "Edição de Perfil", desc: "Se o usuário alterar o texto de deal breakers", color: COLORS.yellow, icon: "②" },
            { when: "Reprocessamento", desc: "Se novos campos forem adicionados ao sistema (batch)", color: COLORS.accent, icon: "③" },
          ].map((item, i) => (
            <div key={i} style={{ padding: 14, background: `${item.color}08`, border: `1px solid ${item.color}20`, borderRadius: 8, textAlign: "center" }}>
              <div style={{ fontSize: 22, marginBottom: 6 }}>{item.icon}</div>
              <div style={{ fontSize: 12, fontWeight: 700, color: item.color }}>{item.when}</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 6 }}>{item.desc}</div>
            </div>
          ))}
        </Card>
      </Section>
    </div>
  );
}

function ScoringPanel() {
  return (
    <div>
      <Section title="DISTRIBUIÇÃO DE PESOS" color={COLORS.accent}>
        <Card>
          <WeightBar label="💖 Linguagem do Amor + O que te atrai" weight={35} color={COLORS.pink} detail="Linguagem do amor (match direto/complementar) + tags de atração em sobreposição" />
          <WeightBar label="🏃 Estilo de Vida" weight={25} color={COLORS.green} detail="Fumo, álcool, exercício, dieta, hobbies, horário online" />
          <WeightBar label="🧠 Valores e Personalidade" weight={25} color={COLORS.blue} detail="MBTI, visão política, religião, situação de vida, hobbies" />
          <WeightBar label="✨ Astrologia" weight={15} color={COLORS.accent} detail="Signo solar (sempre) + mapa completo (se disponível)" />
        </Card>
      </Section>

      <Section title="BLOCO 1 — LINGUAGEM DO AMOR + O QUE ATRAI (35%)" color={COLORS.pink}>
        <Card>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16 }}>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.pink, marginBottom: 10 }}>LINGUAGEM DO AMOR</div>
              <div style={{ background: COLORS.bg, borderRadius: 8, padding: 12, fontSize: 11, lineHeight: 1.8 }}>
                <div><span style={{ color: COLORS.green }}>Match direto</span> <span style={{ color: COLORS.textDim }}>(mesma linguagem)</span> <span style={{ color: COLORS.green, fontWeight: 700 }}>= 100 pts</span></div>
                <div><span style={{ color: COLORS.yellow }}>Complementar</span> <span style={{ color: COLORS.textDim }}>(ex: Atos de Serviço ↔ Tempo de Qualidade)</span> <span style={{ color: COLORS.yellow, fontWeight: 700 }}>= 70 pts</span></div>
                <div><span style={{ color: COLORS.orange }}>Neutro</span> <span style={{ color: COLORS.textDim }}>(sem relação conhecida)</span> <span style={{ color: COLORS.orange, fontWeight: 700 }}>= 40 pts</span></div>
                <div><span style={{ color: COLORS.red }}>Oposto</span> <span style={{ color: COLORS.textDim }}>(ex: Presentes ↔ Toque Físico)</span> <span style={{ color: COLORS.red, fontWeight: 700 }}>= 20 pts</span></div>
              </div>
            </div>
            <div>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.pink, marginBottom: 10 }}>O QUE TE ATRAI (tags)</div>
              <div style={{ background: COLORS.bg, borderRadius: 8, padding: 12, fontSize: 11, lineHeight: 1.8 }}>
                <div style={{ color: COLORS.textDim, marginBottom: 8 }}>Cada tag em comum = pontos diretos</div>
                <div><Badge label="Inteligência" color={COLORS.cyan} /> <Badge label="Humor" color={COLORS.yellow} /></div>
                <div style={{ marginTop: 4 }}><Badge label="Aparência" color={COLORS.pink} /> <Badge label="Bondade" color={COLORS.green} /></div>
                <div style={{ marginTop: 4 }}><Badge label="Ambição" color={COLORS.orange} /></div>
                <div style={{ marginTop: 10, color: COLORS.text, fontSize: 11 }}>
                  <strong>Fórmula:</strong> (tags_em_comum / max(tags_A, tags_B)) × 100
                </div>
              </div>
            </div>
          </div>

          <div style={{ marginTop: 12, background: COLORS.bg, borderRadius: 8, padding: 12 }}>
            <div style={{ fontFamily: "monospace", fontSize: 11, color: COLORS.text }}>
              <span style={{ color: COLORS.pink }}>score_bloco1</span> = (<span style={{ color: COLORS.accent }}>score_linguagem</span> × 0.6) + (<span style={{ color: COLORS.accent }}>score_atracao</span> × 0.4)
            </div>
          </div>
        </Card>
      </Section>

      <Section title="BLOCO 2 — ESTILO DE VIDA (25%)" color={COLORS.green}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, marginBottom: 12, lineHeight: 1.6 }}>
            Cada comparação usa <span style={{ color: COLORS.green, fontWeight: 600 }}>lógica de gradação</span> — não é binário (igual ou diferente).
            Valores próximos pontuam parcialmente.
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 8 }}>
            {[
              { campo: "Fumo", logica: "Igual = 100 · Próximo = 50 · Oposto = 0", ex: "sim↔sim = 100 · sim↔ocasional = 50" },
              { campo: "Álcool", logica: "Igual = 100 · Próximo = 60 · Oposto = 10", ex: "socialmente↔socialmente = 100" },
              { campo: "Exercício", logica: "Ambos sim = 100 · Um sim = 40 · Ambos não = 70", ex: "Se ambos sim → bônus tipo exercício" },
              { campo: "Tipo Exercício", logica: "Bônus se mesma modalidade", ex: "gym↔gym = +20pts bônus" },
              { campo: "Dieta", logica: "Igual = 100 · Próximo = 60 · Oposto = 10", ex: "vegano↔omnivoro = 10pts" },
              { campo: "Hobbies", logica: "(em_comum / total_unico) × 100", ex: "4 de 6 em comum = 67pts" },
            ].map((item, i) => (
              <div key={i} style={{ padding: 10, background: COLORS.bg, borderRadius: 8, border: `1px solid ${COLORS.border}` }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.green }}>{item.campo}</div>
                <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 4 }}>{item.logica}</div>
                <div style={{ fontSize: 9, color: COLORS.textMuted, marginTop: 4, fontStyle: "italic" }}>{item.ex}</div>
              </div>
            ))}
          </div>

          <div style={{ marginTop: 12, background: COLORS.bg, borderRadius: 8, padding: 12 }}>
            <div style={{ fontFamily: "monospace", fontSize: 11, color: COLORS.text }}>
              <span style={{ color: COLORS.green }}>score_bloco2</span> = média_ponderada(<span style={{ color: COLORS.accent }}>fumo</span>×15, <span style={{ color: COLORS.accent }}>alcool</span>×15, <span style={{ color: COLORS.accent }}>exercicio</span>×20, <span style={{ color: COLORS.accent }}>dieta</span>×15, <span style={{ color: COLORS.accent }}>hobbies</span>×25, <span style={{ color: COLORS.accent }}>horario</span>×10)
            </div>
          </div>
        </Card>
      </Section>

      <Section title="BLOCO 3 — VALORES E PERSONALIDADE (25%)" color={COLORS.blue}>
        <Card>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div style={{ padding: 12, background: COLORS.bg, borderRadius: 8 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.blue, marginBottom: 8 }}>MBTI (peso 30% do bloco)</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><span style={{ color: COLORS.green }}>Complementares conhecidos</span> = 90pts</div>
                <div style={{ fontSize: 9, color: COLORS.textMuted, paddingLeft: 8 }}>INFJ↔ENFP, INTJ↔ENTP, INFP↔ENFJ, etc.</div>
                <div><span style={{ color: COLORS.blue }}>Tipos iguais</span> = 70pts</div>
                <div><span style={{ color: COLORS.yellow }}>Neutros</span> = 50pts</div>
                <div><span style={{ color: COLORS.red }}>Com atrito</span> = 20pts</div>
                <div style={{ fontSize: 9, color: COLORS.textMuted, paddingLeft: 8 }}>ESTJ↔INFP, ISTJ↔ENFP, etc.</div>
              </div>
            </div>
            <div style={{ padding: 12, background: COLORS.bg, borderRadius: 8 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.blue, marginBottom: 8 }}>VISÃO POLÍTICA (peso 25% do bloco)</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><span style={{ color: COLORS.green }}>Mesmo espectro</span> = 100pts</div>
                <div><span style={{ color: COLORS.yellow }}>Diferente + ambos "dataria"</span> = 60pts</div>
                <div><span style={{ color: COLORS.orange }}>Diferente + um "não dataria"</span> = 25pts</div>
                <div><span style={{ color: COLORS.red }}>Diferente + ambos "não dataria"</span> = 0pts</div>
              </div>
            </div>
            <div style={{ padding: 12, background: COLORS.bg, borderRadius: 8 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.blue, marginBottom: 8 }}>RELIGIÃO (peso 25% do bloco)</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><span style={{ color: COLORS.green }}>Mesma religião</span> = 100pts</div>
                <div><span style={{ color: COLORS.yellow }}>Diferente com tolerância</span> = 55pts</div>
                <div><span style={{ color: COLORS.red }}>Oposta sem tolerância</span> = 10pts</div>
              </div>
            </div>
            <div style={{ padding: 12, background: COLORS.bg, borderRadius: 8 }}>
              <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.blue, marginBottom: 8 }}>SITUAÇÃO + ÁREA (peso 20% do bloco)</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><span style={{ color: COLORS.green }}>Mesma situação + área similar</span> = 100pts</div>
                <div><span style={{ color: COLORS.yellow }}>Mesma situação, área diferente</span> = 60pts</div>
                <div><span style={{ color: COLORS.blue }}>Situação diferente</span> = 40pts</div>
              </div>
            </div>
          </div>
        </Card>
      </Section>

      <Section title="PENALIZAÇÕES (aplicadas SOBRE o score)" color={COLORS.orange}>
        <Card>
          <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
            <div style={{ padding: 14, background: COLORS.orangeDim, borderRadius: 8, border: `1px solid ${COLORS.orange}30` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.orange }}>Tipo de Relacionamento Diferente</div>
                  <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 4 }}>Long-term ↔ Open Relation, Monogâmico ↔ Poliamoroso</div>
                </div>
                <div style={{ fontSize: 18, fontWeight: 800, color: COLORS.red }}>-30 a -40</div>
              </div>
            </div>
            <div style={{ padding: 14, background: COLORS.yellowDim, borderRadius: 8, border: `1px solid ${COLORS.yellow}30` }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div>
                  <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.yellow }}>Deal Breakers de Grau Médio</div>
                  <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 4 }}>Valores próximos ao rejeitado (configurado no JSON da IA)</div>
                </div>
                <div style={{ fontSize: 18, fontWeight: 800, color: COLORS.orange }}>-15 a -40</div>
              </div>
            </div>
          </div>

          <div style={{ marginTop: 16, background: COLORS.bg, borderRadius: 8, padding: 12 }}>
            <div style={{ fontFamily: "monospace", fontSize: 11, color: COLORS.text, lineHeight: 1.8 }}>
              <div style={{ color: COLORS.accent }}>// FÓRMULA FINAL:</div>
              <div><span style={{ color: COLORS.green }}>score_bruto</span> = (bloco1 × 0.35) + (bloco2 × 0.25) + (bloco3 × 0.25) + (bloco4 × 0.15)</div>
              <div><span style={{ color: COLORS.orange }}>penalizacoes</span> = tipo_relacionamento + deal_breakers_medios</div>
              <div><span style={{ color: COLORS.cyan, fontWeight: 700 }}>score_final</span> = max(0, <span style={{ color: COLORS.green }}>score_bruto</span> - <span style={{ color: COLORS.orange }}>penalizacoes</span>)</div>
            </div>
          </div>
        </Card>
      </Section>
    </div>
  );
}

function AstroPanel() {
  return (
    <div>
      <Section title="NÍVEL 1 — SIGNO SOLAR (sempre disponível)" color={COLORS.accent}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, marginBottom: 16, lineHeight: 1.6 }}>
            Todo usuário tem signo solar (informado no onboarding). A compatibilidade segue a <span style={{ color: COLORS.accent }}>tabela clássica de elementos</span>.
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 8, marginBottom: 16 }}>
            {[
              { el: "🔥 Fogo", signos: "Áries, Leão, Sagitário", color: COLORS.red },
              { el: "🌍 Terra", signos: "Touro, Virgem, Capricórnio", color: COLORS.green },
              { el: "💨 Ar", signos: "Gêmeos, Libra, Aquário", color: COLORS.cyan },
              { el: "💧 Água", signos: "Câncer, Escorpião, Peixes", color: COLORS.blue },
            ].map((item, i) => (
              <div key={i} style={{ padding: 12, background: `${item.color}08`, border: `1px solid ${item.color}25`, borderRadius: 8, textAlign: "center" }}>
                <div style={{ fontSize: 12, fontWeight: 700, color: item.color }}>{item.el}</div>
                <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 6 }}>{item.signos}</div>
              </div>
            ))}
          </div>

          <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.accent, marginBottom: 8 }}>TABELA DE COMPATIBILIDADE POR ELEMENTO</div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
            {[
              { combo: "Mesmo elemento", pts: "85", color: COLORS.green, desc: "Fogo↔Fogo, Terra↔Terra..." },
              { combo: "Fogo ↔ Ar", pts: "90", color: COLORS.green, desc: "Elementos complementares" },
              { combo: "Terra ↔ Água", pts: "90", color: COLORS.green, desc: "Elementos complementares" },
              { combo: "Fogo ↔ Terra", pts: "40", color: COLORS.yellow, desc: "Compatibilidade moderada" },
              { combo: "Ar ↔ Água", pts: "40", color: COLORS.yellow, desc: "Compatibilidade moderada" },
              { combo: "Fogo ↔ Água", pts: "25", color: COLORS.red, desc: "Elementos opostos" },
            ].map((item, i) => (
              <div key={i} style={{ display: "flex", justifyContent: "space-between", alignItems: "center", padding: 10, background: COLORS.bg, borderRadius: 8 }}>
                <div>
                  <div style={{ fontSize: 11, fontWeight: 600, color: item.color }}>{item.combo}</div>
                  <div style={{ fontSize: 9, color: COLORS.textMuted }}>{item.desc}</div>
                </div>
                <div style={{ fontSize: 14, fontWeight: 800, color: item.color }}>{item.pts}</div>
              </div>
            ))}
          </div>
        </Card>
      </Section>

      <Section title="NÍVEL 2 — MAPA ASTRAL COMPLETO (opcional)" color={COLORS.pink}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, marginBottom: 16, lineHeight: 1.6 }}>
            Ativado quando o usuário fornece <span style={{ color: COLORS.pink }}>data + horário + local de nascimento</span>.
            Cada ponto astrológico gera uma micro-pontuação que substitui o score do Nível 1.
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10 }}>
            {[
              { ponto: "☀️ Sol", repr: "Identidade, ego", peso: "25%", desc: "Base da compatibilidade — como duas pessoas 'se enxergam'" },
              { ponto: "🌙 Lua", repr: "Emoções, vida íntima", peso: "25%", desc: "Crucial para convivência — como lidam com sentimentos" },
              { ponto: "⬆️ Ascendente", repr: "Primeira impressão", peso: "10%", desc: "Atração inicial — o que sentem ao se conhecer" },
              { ponto: "♀️ Vênus", repr: "Como ama", peso: "20%", desc: "Estilo romântico — presentes, afeto, prioridades no amor" },
              { ponto: "♂️ Marte", repr: "Atração, conquista", peso: "12%", desc: "Tensão sexual, como perseguem o que querem" },
              { ponto: "☿ Mercúrio", repr: "Comunicação", peso: "8%", desc: "Como conversam, resolvem conflitos, pensam" },
            ].map((item, i) => (
              <div key={i} style={{ padding: 12, background: COLORS.bg, borderRadius: 8, border: `1px solid ${COLORS.border}` }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 6 }}>
                  <div style={{ fontSize: 13, fontWeight: 700, color: COLORS.text }}>{item.ponto}</div>
                  <Badge label={item.peso} color={COLORS.accent} />
                </div>
                <div style={{ fontSize: 10, color: COLORS.pink, fontWeight: 600 }}>{item.repr}</div>
                <div style={{ fontSize: 10, color: COLORS.textDim, marginTop: 6 }}>{item.desc}</div>
              </div>
            ))}
          </div>

          <div style={{ marginTop: 16, background: COLORS.bg, borderRadius: 8, padding: 12 }}>
            <div style={{ fontFamily: "monospace", fontSize: 11, color: COLORS.text, lineHeight: 1.8 }}>
              <div style={{ color: COLORS.accent }}>// Cada ponto usa a mesma tabela de elementos:</div>
              <div><span style={{ color: COLORS.pink }}>score_astro</span> = (sol×0.25) + (lua×0.25) + (venus×0.20) + (marte×0.12) + (ascendente×0.10) + (mercurio×0.08)</div>
            </div>
          </div>

          <div style={{ marginTop: 12, padding: 12, background: COLORS.accentGlow, borderRadius: 8, border: `1px solid ${COLORS.accent}30` }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.accent, marginBottom: 4 }}>FALLBACK INTELIGENTE</div>
            <div style={{ fontSize: 10, color: COLORS.textDim }}>
              Se apenas um dos dois tem mapa completo → usa Nível 1 (signo solar) para ambos.
              O mapa completo só ativa quando AMBOS preencheram os dados completos.
            </div>
          </div>
        </Card>
      </Section>
    </div>
  );
}

function DisplayPanel() {
  const [mockScore] = useState(78);
  return (
    <div>
      <Section title="FAIXAS DE COMPATIBILIDADE" color={COLORS.accent}>
        <Card>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            {[
              { range: "85–100", label: "✨ Conexão Rara", color: COLORS.accent, desc: "Match excepcional em quase todos os aspectos" },
              { range: "70–84", label: "💚 Alta Compatibilidade", color: COLORS.green, desc: "Forte afinidade com poucas divergências" },
              { range: "50–69", label: "💛 Compatível com Diferenças", color: COLORS.yellow, desc: "Base sólida com pontos de atenção" },
              { range: "30–49", label: "🟠 Poucos pontos em comum", color: COLORS.orange, desc: "Diferenças significativas na maioria dos aspectos" },
              { range: "0–29", label: "❌ Improvável", color: COLORS.red, desc: "Perfis muito divergentes" },
            ].map((f, i) => (
              <div key={i} style={{ display: "flex", alignItems: "center", gap: 12, padding: 10, background: `${f.color}08`, borderRadius: 8, border: `1px solid ${f.color}20` }}>
                <div style={{ fontSize: 12, fontWeight: 800, color: f.color, minWidth: 55 }}>{f.range}</div>
                <div style={{ fontSize: 13, fontWeight: 700, color: f.color, minWidth: 180 }}>{f.label}</div>
                <div style={{ fontSize: 11, color: COLORS.textDim }}>{f.desc}</div>
              </div>
            ))}
          </div>
        </Card>
      </Section>

      <Section title="MOCKUP — COMO APARECE PARA O USUÁRIO" color={COLORS.green}>
        <Card style={{ maxWidth: 380, margin: "0 auto", background: "#111118", borderRadius: 20, padding: 24, border: `1px solid ${COLORS.border}` }}>
          <div style={{ textAlign: "center", marginBottom: 20 }}>
            <div style={{ width: 70, height: 70, borderRadius: "50%", background: `linear-gradient(135deg, ${COLORS.accent}, ${COLORS.pink})`, margin: "0 auto 12px", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 28 }}>
              💚
            </div>
            <div style={{ fontSize: 32, fontWeight: 800, color: COLORS.green, letterSpacing: "-0.02em" }}>{mockScore}%</div>
            <div style={{ fontSize: 14, fontWeight: 600, color: COLORS.green, marginTop: 4 }}>Alta Compatibilidade</div>
          </div>

          <div style={{ display: "flex", gap: 6, marginBottom: 20 }}>
            {[
              { label: "Amor", pct: 88, color: COLORS.pink },
              { label: "Vida", pct: 72, color: COLORS.green },
              { label: "Valores", pct: 65, color: COLORS.blue },
              { label: "Astro", pct: 82, color: COLORS.accent },
            ].map((b, i) => (
              <div key={i} style={{ flex: 1, textAlign: "center" }}>
                <div style={{ fontSize: 9, color: COLORS.textMuted, marginBottom: 4 }}>{b.label}</div>
                <div style={{ height: 4, background: COLORS.border, borderRadius: 2, overflow: "hidden" }}>
                  <div style={{ height: "100%", width: `${b.pct}%`, background: b.color, borderRadius: 2 }} />
                </div>
                <div style={{ fontSize: 10, color: b.color, fontWeight: 700, marginTop: 2 }}>{b.pct}</div>
              </div>
            ))}
          </div>

          <div style={{ marginBottom: 14 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.green, marginBottom: 6 }}>✅ Muito parecidos em:</div>
            <div style={{ fontSize: 11, color: COLORS.textDim, lineHeight: 1.7, paddingLeft: 8 }}>
              Vocês compartilham a mesma linguagem do amor (Toque Físico) e ambos valorizam humor e inteligência.
              O estilo de vida também é parecido — ambos frequentam academia e são sociais com bebidas.
            </div>
          </div>

          <div style={{ marginBottom: 14 }}>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.blue, marginBottom: 6 }}>🔄 Diferenças que podem enriquecer:</div>
            <div style={{ fontSize: 11, color: COLORS.textDim, lineHeight: 1.7, paddingLeft: 8 }}>
              Seus MBTIs (INFJ e ENFP) são um dos pares mais complementares — equilíbrio entre profundidade e espontaneidade.
              Na astrologia, Lua em Câncer com Lua em Peixes cria uma conexão emocional intensa.
            </div>
          </div>

          <div>
            <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.orange, marginBottom: 6 }}>⚠️ Ponto de atenção:</div>
            <div style={{ fontSize: 11, color: COLORS.textDim, lineHeight: 1.7, paddingLeft: 8 }}>
              Visões políticas diferentes — mas ambos responderam que estariam abertos a datar alguém com perspectiva diferente.
            </div>
          </div>
        </Card>
      </Section>

      <Section title="GERAÇÃO DOS MOTIVOS (IA)" color={COLORS.cyan}>
        <Card>
          <div style={{ fontSize: 12, color: COLORS.textDim, lineHeight: 1.7, marginBottom: 16 }}>
            Após o score ser calculado, uma <span style={{ color: COLORS.cyan }}>segunda IA</span> recebe o score detalhado de cada bloco + os dados
            de ambos os perfis e gera os 3 blocos explicativos em linguagem natural, amigável e pessoal.
          </div>

          <div style={{ background: COLORS.bg, borderRadius: 8, padding: 16, fontFamily: "monospace", fontSize: 10, color: COLORS.text, lineHeight: 1.8 }}>
            <div style={{ color: COLORS.cyan, fontWeight: 700 }}>// PROMPT DA IA DE MOTIVOS</div>
            <br />
            <div style={{ color: COLORS.textDim }}>Dados recebidos:</div>
            <div style={{ color: COLORS.green }}>- score_total: 78</div>
            <div style={{ color: COLORS.green }}>- score_amor: 88 (linguagem: match direto, 3/5 tags)</div>
            <div style={{ color: COLORS.green }}>- score_vida: 72 (fumo ok, exerc match, dieta diff)</div>
            <div style={{ color: COLORS.green }}>- score_valores: 65 (MBTI complementar, politica diff)</div>
            <div style={{ color: COLORS.green }}>- score_astro: 82 (lua-lua excelente, venus bom)</div>
            <div style={{ color: COLORS.green }}>- penalizacoes: -5 (politica com tolerancia)</div>
            <br />
            <div style={{ color: COLORS.textDim }}>Gere exatamente 3 blocos:</div>
            <div style={{ color: COLORS.green }}>1. "Muito parecidos em" → pontos &gt;= 75</div>
            <div style={{ color: COLORS.blue }}>2. "Diferenças que enriquecem" → complementaridades</div>
            <div style={{ color: COLORS.orange }}>3. "Ponto de atenção" → scores mais baixos ou penalizações</div>
            <br />
            <div style={{ color: COLORS.textDim }}>Regras: linguagem amigável, max 3 frases por bloco,</div>
            <div style={{ color: COLORS.textDim }}>nunca revelar números exatos do score interno,</div>
            <div style={{ color: COLORS.textDim }}>sempre dar contexto positivo mesmo nos pontos de atenção.</div>
          </div>
        </Card>
      </Section>
    </div>
  );
}

function DataflowPanel() {
  return (
    <div>
      <Section title="FLUXO COMPLETO: DO ONBOARDING AO MATCH" color={COLORS.accent}>
        <Card>
          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
            <FlowNode label="① ONBOARDING COMPLETO" sublabel="Usuário preenche todos os campos + texto de deal breakers" color={COLORS.cyan} type="terminal" />
            <Arrow color={COLORS.cyan} />
            <FlowNode label="② IA PROCESSA DEAL BREAKERS" sublabel="Texto livre → JSON estruturado (1x, assíncrono)" color={COLORS.accent} type="process" />
            <Arrow color={COLORS.accent} />
            <FlowNode label="③ PERFIL SALVO NO BANCO" sublabel="Todos os campos + deal_breakers_json + deal_breakers_texto" color={COLORS.blue} type="process" />
            <Arrow color={COLORS.yellow} label="QUANDO DOIS PERFIS SE ENCONTRAM" />
            <FlowNode label="④ FILTRO: GÊNERO/ORIENTAÇÃO" sublabel="A.quer_ver inclui B.genero && vice-versa" color={COLORS.red} type="decision" />
            <SplitArrow leftLabel="NÃO PASSA" rightLabel="PASSA ✓" leftColor={COLORS.red} rightColor={COLORS.green} />
            <div style={{ display: "flex", gap: 16, width: "100%" }}>
              <FlowNode label="ELIMINADO" color={COLORS.red} type="eliminated" width="40%" />
              <div style={{ width: "60%", display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
                <FlowNode label="⑤ FILTRO: DEAL BREAKERS ELIMINATÓRIOS" sublabel="JSON de A contra perfil B + JSON de B contra perfil A" color={COLORS.red} type="decision" />
                <SplitArrow leftLabel="BATE COM REJEIÇÃO" rightLabel="NÃO BATE ✓" leftColor={COLORS.red} rightColor={COLORS.green} />
              </div>
            </div>
          </div>

          <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3, marginTop: 8 }}>
            <FlowNode label="⑥ APLICA PENALIZAÇÕES" sublabel="Tipo de relacionamento (-30~-40) + Deal breakers médios (-15~-40)" color={COLORS.orange} type="process" />
            <Arrow color={COLORS.accent} />
            <FlowNode label="⑦ CALCULA 4 BLOCOS DE SCORE" sublabel="Amor (35%) + Estilo (25%) + Valores (25%) + Astro (15%)" color={COLORS.accent} type="process" />
            <Arrow color={COLORS.accent} />
            <FlowNode label="⑧ SCORE FINAL = BLOCOS - PENALIZAÇÕES" sublabel="Resultado entre 0 e 100" color={COLORS.green} type="process" />
            <Arrow color={COLORS.cyan} />
            <FlowNode label="⑨ IA GERA MOTIVOS" sublabel="Recebe scores detalhados → gera 3 blocos explicativos" color={COLORS.cyan} type="process" />
            <Arrow color={COLORS.green} />
            <FlowNode label="⑩ EXIBE PARA O USUÁRIO" sublabel="Score + Label + Parecidos + Complementares + Atenções" color={COLORS.green} type="terminal" />
          </div>
        </Card>
      </Section>

      <Section title="ARQUITETURA TÉCNICA" color={COLORS.blue}>
        <Card>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
            <div style={{ padding: 14, background: COLORS.bg, borderRadius: 10, border: `1px solid ${COLORS.cyan}20` }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.cyan, marginBottom: 10 }}>IA #1 — Deal Breaker Parser</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><strong style={{ color: COLORS.text }}>Quando:</strong> Onboarding / edição de perfil</div>
                <div><strong style={{ color: COLORS.text }}>Input:</strong> texto livre + mapa_campos</div>
                <div><strong style={{ color: COLORS.text }}>Output:</strong> JSON estruturado</div>
                <div><strong style={{ color: COLORS.text }}>Frequência:</strong> 1x por usuário (+ re-edições)</div>
                <div><strong style={{ color: COLORS.text }}>Latência:</strong> Assíncrona (background job)</div>
                <div><strong style={{ color: COLORS.text }}>Modelo sugerido:</strong> Claude Haiku (rápido, barato)</div>
              </div>
            </div>
            <div style={{ padding: 14, background: COLORS.bg, borderRadius: 10, border: `1px solid ${COLORS.accent}20` }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.accent, marginBottom: 10 }}>IA #2 — Gerador de Motivos</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><strong style={{ color: COLORS.text }}>Quando:</strong> Após cálculo de score</div>
                <div><strong style={{ color: COLORS.text }}>Input:</strong> scores detalhados + dados dos 2 perfis</div>
                <div><strong style={{ color: COLORS.text }}>Output:</strong> 3 blocos de texto explicativo</div>
                <div><strong style={{ color: COLORS.text }}>Frequência:</strong> 1x por par (cacheável)</div>
                <div><strong style={{ color: COLORS.text }}>Latência:</strong> Pode ser pré-calculado ou on-demand</div>
                <div><strong style={{ color: COLORS.text }}>Modelo sugerido:</strong> Claude Sonnet (qualidade textual)</div>
              </div>
            </div>
            <div style={{ padding: 14, background: COLORS.bg, borderRadius: 10, border: `1px solid ${COLORS.green}20` }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.green, marginBottom: 10 }}>Motor de Score (código)</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><strong style={{ color: COLORS.text }}>O que é:</strong> Função determinística, sem IA</div>
                <div><strong style={{ color: COLORS.text }}>Onde roda:</strong> Backend (server-side)</div>
                <div><strong style={{ color: COLORS.text }}>Input:</strong> 2 perfis completos + JSONs de deal breakers</div>
                <div><strong style={{ color: COLORS.text }}>Output:</strong> score_total + scores por bloco</div>
                <div><strong style={{ color: COLORS.text }}>Performance:</strong> &lt; 5ms por par</div>
                <div><strong style={{ color: COLORS.text }}>Pode ser:</strong> Pré-calculado em batch ou on-demand</div>
              </div>
            </div>
            <div style={{ padding: 14, background: COLORS.bg, borderRadius: 10, border: `1px solid ${COLORS.orange}20` }}>
              <div style={{ fontSize: 12, fontWeight: 700, color: COLORS.orange, marginBottom: 10 }}>Cache e Otimização</div>
              <div style={{ fontSize: 10, color: COLORS.textDim, lineHeight: 1.7 }}>
                <div><strong style={{ color: COLORS.text }}>Score:</strong> Cachear por par (invalidar se perfil mudar)</div>
                <div><strong style={{ color: COLORS.text }}>Motivos:</strong> Cachear por par (invalidar com score)</div>
                <div><strong style={{ color: COLORS.text }}>Deal breakers JSON:</strong> Cachear no perfil</div>
                <div><strong style={{ color: COLORS.text }}>Filtros eliminatórios:</strong> Rodar em query SQL/NoSQL</div>
                <div><strong style={{ color: COLORS.text }}>Sugestão:</strong> Background job calcula top matches</div>
              </div>
            </div>
          </div>
        </Card>
      </Section>
    </div>
  );
}

// ─── MAIN APP ───
export default function App() {
  const [activeTab, setActiveTab] = useState("overview");

  const panels = {
    overview: <OverviewPanel />,
    filters: <FiltersPanel />,
    ai: <AIPanel />,
    scoring: <ScoringPanel />,
    astro: <AstroPanel />,
    display: <DisplayPanel />,
    dataflow: <DataflowPanel />,
  };

  return (
    <div style={{ minHeight: "100vh", background: COLORS.bg, color: COLORS.text, fontFamily: "'Segoe UI', -apple-system, sans-serif" }}>
      {/* Header */}
      <div style={{ padding: "20px 24px 0", borderBottom: `1px solid ${COLORS.border}` }}>
        <div style={{ fontSize: 11, fontWeight: 700, color: COLORS.accent, letterSpacing: "0.15em", textTransform: "uppercase", marginBottom: 4 }}>
          Arquitetura Completa
        </div>
        <div style={{ fontSize: 20, fontWeight: 800, color: COLORS.text, letterSpacing: "-0.02em", marginBottom: 16 }}>
          Sistema de Compatibilidade
        </div>

        {/* Tabs */}
        <div style={{ display: "flex", gap: 2, overflowX: "auto", paddingBottom: 0 }}>
          {tabs.map((tab) => (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              style={{
                padding: "8px 14px",
                fontSize: 11,
                fontWeight: activeTab === tab.id ? 700 : 500,
                color: activeTab === tab.id ? COLORS.accent : COLORS.textMuted,
                background: activeTab === tab.id ? COLORS.accentGlow : "transparent",
                border: "none",
                borderBottom: activeTab === tab.id ? `2px solid ${COLORS.accent}` : "2px solid transparent",
                cursor: "pointer",
                whiteSpace: "nowrap",
                borderRadius: "6px 6px 0 0",
                transition: "all 0.2s ease",
              }}
            >
              <span style={{ marginRight: 5 }}>{tab.icon}</span>
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Content */}
      <div style={{ padding: 24, maxWidth: 900, margin: "0 auto" }}>
        {panels[activeTab]}
      </div>
    </div>
  );
}
