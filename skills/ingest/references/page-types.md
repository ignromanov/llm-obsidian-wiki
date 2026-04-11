# Determining Page Type

Assign `type:` based on the nature of the content.

| Type | Content describes... | Examples |
|------|---------------------|----------|
| `concept` | Definitions, mechanisms, mental models | Zero-knowledge proofs, Magic Dust, URL encoding |
| `entity` | External tools, technologies, protocols | Request Finance, x402, EIP-7702 |
| `architecture` | Internal system design, components | Codec pipeline, FSD layer structure |
| `decision` | Why X was chosen over Y (ADRs) | Why Arbitrum over Optimism, Why no backend |
| `strategy` | Plans, goals, metrics, roadmap items | GTM plan, grant pipeline, growth targets |
| `org` | Companies, foundations, DAOs | Ethereum Foundation, Coinbase, Optimism Collective |
| `comparison` | X vs Y evaluations | Request Finance vs VoidPay, L2 fee comparison |
| `open-question` | Unknowns requiring future research | Should we support Solana?, MPC wallet feasibility |
| `source-summary` | Summary of a single raw source (Step 3) | src-competitive-landscape-q1 |
| `synthesis` | Cross-source analysis combining multiple sources | Market landscape overview |

## Disambiguation Rule

When ambiguous, prefer the more specific type. A page about "Why we picked Viem over Ethers" is `decision`, not `concept`.
