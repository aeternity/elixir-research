# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :aecore, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:aecore, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#

persistence_path =
  case System.get_env("PERSISTENCE_PATH") do
    nil -> "apps/aecore/priv/rox_db/"
    env -> env
  end

config :aecore, :persistence,
  path: Path.absname(persistence_path),
  write_options: [sync: true, disable_wal: false]

accounts_path =
  case System.get_env("ACCOUNTS_PATH") do
    nil -> "apps/aecore/config/genesis/"
    env -> env
  end

config :aecore, :account_path, path: Path.absname(accounts_path)

new_candidate_nonce_count =
  case System.get_env("NEW_CANDIDATE_NONCE_COUNT") do
    nil -> 10
    env -> env
  end

config :aecore, :pow,
  new_candidate_nonce_count: new_candidate_nonce_count,
  bin_dir: Path.absname("apps/aecore/priv/cuckoo/bin"),
  params: {"./lean16", "-t 5", 16},
  max_target_change: 1,
  genesis_header: %{
    height: 0,
    prev_hxash: <<0::256>>,
    txs_hash: <<0::256>>,
    root_hash: <<0::256>>,
    time: 1_507_275_094_308,
    nonce: 46,
    # 256 if key is 32 bytes
    miner: <<0::264>>,
    pow_evidence: [
      1656,
      2734,
      2879,
      3388,
      4324,
      7350,
      7500,
      8237,
      8383,
      8970,
      9791,
      9799,
      13_460,
      14_799,
      16_196,
      18_360,
      18_395,
      18_815,
      19_037,
      19_181,
      19_819,
      19_824,
      21_921,
      22_577,
      22_823,
      22_943,
      24_148,
      24_883,
      24_996,
      25_922,
      26_228,
      26_358,
      26_475,
      26_804,
      27_998,
      28_638,
      29_706,
      30_489,
      30_759,
      31_453,
      31_562,
      32_630
    ],
    version: 1,
    target: 0x2100FFFF
  }

sync_port =
  case System.get_env("SYNC_PORT") do
    nil -> 3015
    env -> String.to_integer(env)
  end

config :aecore, :peers,
  ranch_acceptors: 10,
  sync_port: sync_port

config :aecore, :miner, resumed_by_default: false

config :aecore, :tx_data,
  minimum_fee: 10,
  max_txs_per_block: 100,
  blocks_ttl_per_token: 1000,
  oracle_registration_base_fee: 4,
  oracle_query_base_fee: 2,
  oracle_response_base_fee: 2,
  oracle_extend_base_fee: 1
