# 14 — Páginas legais e suporte

Obrigatórias antes de subir a campanha (a Meta reprova anúncios sem política de privacidade e o
PayPal usa a refund policy em disputas). Conteúdo em inglês americano. Este spec não substitui
orientação jurídica/contábil; é um checklist de conferência.

## Páginas

| Rota | Título | Conteúdo mínimo |
|---|---|---|
| `/privacy` | Privacy Policy | Quem opera (nome/razão social, país), dados coletados (email, nome, telefone com opt-in, IP, user agent, cookies, UTMs, pixels Meta/GA4), finalidade (entrega, suporte, medição de anúncios), compartilhamento (PayPal, Twilio, provedor de email, Meta, Google, hospedagem), retenção, direitos do usuário (acesso, exclusão — contato via email), cookies e como desativar, menção a CCPA (aplicabilidade) e LGPD (operador brasileiro), contato |
| `/terms` | Terms of Service | Natureza do produto (digital, entrega por link), licença de uso pessoal e não transferível, proibição de redistribuição, preço em USD, entrega imediata após confirmação, validade do link e reenvio, limitação de responsabilidade, isenção (não é aconselhamento médico/psicológico), lei aplicável, contato |
| `/refund-policy` | Refund Policy | Prazo (**14 dias**, alinhado a `refund_days` do produto — o texto DEVE ler o valor do produto ou ser genérico), como solicitar (email ao suporte com o email da compra), prazo de processamento, revogação do acesso após reembolso, disputas |

Implementação: views estáticas ERB em `app/views/legal_pages/` (texto versionado no repositório), com
`last_updated` exibido. `Product#refund_days` interpolado na refund policy quando acessada com contexto
de produto; caso contrário, texto padrão "14 days".

## Rodapé (LP, Thank You, recuperação de acesso)

```
© {year} DevBatista · support@devbatista.online · Privacy Policy · Terms of Service · Refund Policy
```

## Suporte

- `SUPPORT_EMAIL` = `support@devbatista.online` com caixa real monitorada (redirecionamento para o email pessoal é aceitável).
- Respostas de WhatsApp são encaminhadas para esse email (spec 09).
- SLA interno: responder em até 24 h úteis (disputas do PayPal dependem de resposta rápida).

## Emails (CAN-SPAM)

Emails transacionais são isentos de opt-out, mas DEVEM ter identificação clara do remetente e endereço
de contato. Nenhum email de marketing no MVP.

## WhatsApp (TCPA / política Meta)

- Consentimento prévio, explícito e registrado (checkbox desmarcada, texto salvo, data/hora).
- Texto do opt-in na LP: *"Send my download link on WhatsApp too. Standard messaging rates may apply. Reply STOP to opt out."*
- Somente mensagens transacionais.

## Fiscal (fora do código, mas bloqueia lançamento)

- [ ] Enquadramento no Brasil definido com contador (MEI / Simples / PF) e registro das entradas do PayPal.
- [ ] Sales tax nos EUA: monitorar nexus econômico por estado; sem obrigação no volume do MVP.
- [ ] Conteúdo do PDF original; imagens e fontes com licença comercial.

## Critérios de aceite

- [ ] As três páginas respondem 200, têm layout consistente com a LP e links no rodapé de todas as páginas públicas.
- [ ] Refund policy exibe o mesmo número de dias configurado no produto.
- [ ] Facebook Business Manager aceita a URL da política de privacidade na verificação do domínio.
- [ ] Email de suporte recebe e responde uma mensagem de teste.
