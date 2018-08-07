defmodule Aecore.Chain.Block do
  @moduledoc """
  Structure of the block
  """
  alias Aecore.Account.Account
  alias Aecore.Account.AccountStateTree
  alias Aecore.Chain.Worker, as: Chain
  alias Aecore.Chain.Block
  alias Aecore.Chain.Header
  alias Aecore.Chain.Chainstate
  alias Aecore.Tx.SignedTx
  alias Aecore.Chain.BlockValidation
  alias Aeutil.Genesis
  alias Aeutil.Serialization

  @type t :: %Block{
          header: Header.t(),
          txs: list(SignedTx.t())
        }
  # was changed to match current Epoch's block version
  @current_block_version Application.get_env(:aecore, :version)[:block]

  defstruct [:header, :txs]
  use ExConstructor

  @spec current_block_version() :: non_neg_integer()
  def current_block_version do
    @current_block_version
  end

  @spec genesis_header() :: Header.t()
  defp genesis_header do
    header = Application.get_env(:aecore, :pow)[:genesis_header]
    header1 = %{
      height: 0,
      prev_hash: <<0::256>>,
      txs_hash: <<0::256>>,
      root_hash: Chainstate.calculate_root_hash(Chain.chain_state),
      time: 0,
      nonce: 0,
      miner: <<0::256>>,
      pow_evidence: :no_value,
      version: 15,
      target: 0x2100FFFF
    }

    struct(Header, header)
  end

  def genesis_hash do
    BlockValidation.block_header_hash(genesis_header())
  end

  @spec genesis_block() :: Block.t()
  def genesis_block do
    header = genesis_header()
    %Block{header: header, txs: []}
  end

  def genesis_populated_tree() do
    genesis_populated_tree(Genesis.preset_accounts)
  end

  def genesis_populated_tree(accounts) do
    Enum.reduce(
      accounts,
      AccountStateTree.init_empty(),
      fn {k, v}, acc -> AccountStateTree.put(acc, k, Account.new(%{balance: v, nonce: 0, pubkey: k})) end
    )
  end

  @spec rlp_encode(non_neg_integer(), non_neg_integer(), Block.t()) ::
          binary() | {:error, String.t()}
  def rlp_encode(tag, _version, %Block{} = block) do
    header_bin = Serialization.header_to_binary(block.header)

    txs =
      for tx <- block.txs do
        Serialization.rlp_encode(tx, :signedtx)
      end

    list = [
      tag,
      block.header.version,
      header_bin,
      txs
    ]

    try do
      ExRLP.encode(list)
    rescue
      e -> {:error, "#{__MODULE__}: " <> Exception.message(e)}
    end
  end

  def rlp_encode(data) do
    {:error, "#{__MODULE__}: Invalid block or header struct #{inspect(data)}"}
  end

  @spec rlp_decode(list()) :: Block.t() | {:error, String.t()}
  def rlp_decode([header_bin, txs]) do
    txs_list =
      for tx <- txs do
        Serialization.rlp_decode(tx)
      end

    case txs_list_valid?(txs_list) do
      true -> Block.new(%{header: Serialization.binary_to_header(header_bin), txs: txs_list})
      false -> {:error, "#{__MODULE__} : Illegal SignedTx's serialization"}
    end
  end

  def rlp_decode(data) do
    {:error, "#{__MODULE__} : Illegal block serialization: #{inspect(data)} "}
  end

  @spec txs_list_valid?(list()) :: boolean()
  defp txs_list_valid?(txs_list) do
    Enum.all?(txs_list, fn
      {:error, _reason} -> false
      %SignedTx{} -> true
    end)
  end
end
