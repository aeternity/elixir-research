defmodule Aecore.Channel.Tx.ChannelCloseMutalTx do
  @moduledoc """
  Aecore structure of ChannelCloseMutalTx transaction data.
  """

  use Aecore.Tx.Transaction

  alias Aecore.Channel.Tx.ChannelCloseMutalTx
  alias Aecore.Tx.DataTx
  alias Aecore.Account.{Account, AccountStateTree}
  alias Aecore.Chain.Chainstate
  alias Aecore.Channel.{ChannelStateTree, ChannelStateOnChain}
  alias Aecore.Chain.Identifier

  require Logger

  @version 1

  @typedoc "Expected structure for the ChannelCloseMutal Transaction"
  @type payload :: %{
          channel_id: binary(),
          initiator_amount: non_neg_integer(),
          responser_amount: non_neg_integer()
        }

  @typedoc "Reason for the error"
  @type reason :: String.t()

  @typedoc "Structure that holds specific transaction info in the chainstate."
  @type tx_type_state() :: ChannelStateTree.t()

  @typedoc "Structure of the ChannelMutalClose Transaction type"
  @type t :: %ChannelCloseMutalTx{
          channel_id: binary(),
          initiator_amount: non_neg_integer(),
          responder_amount: non_neg_integer()
        }

  @doc """
  Definition of Aecore ChannelCloseMutalTx structure

  ## Parameters
  - channel_id: channel id
  - initiator_amount: amount that account first on the senders list commits
  - responser_amount: amount that account second on the senders list commits
  """
  defstruct [:channel_id, :initiator_amount, :responder_amount]
  use ExConstructor

  @spec get_chain_state_name :: :channels
  def get_chain_state_name, do: :channels

  def chainstate_senders?(), do: true

  @spec senders_from_chainstate(ChannelMutalCloseTx.t(), Chainstate.t()) :: list(binary())
  def senders_from_chainstate(%ChannelCloseMutalTx{channel_id: channel_id}, chainstate) do
    case ChannelStateTree.get(chainstate.channels, channel_id) do
      %ChannelStateOnChain{} = channel ->
        [channel.initiator_pubkey, channel.responder_pubkey]

      :none ->
        []
    end
  end

  @spec init(payload()) :: ChannelCloseMutalTx.t()
  def init(
        %{
          channel_id: channel_id,
          initiator_amount: initiator_amount,
          responder_amount: responder_amount
        } = _payload
      ) do
    %ChannelCloseMutalTx{
      channel_id: channel_id,
      initiator_amount: initiator_amount,
      responder_amount: responder_amount
    }
  end

  @doc """
  Checks transactions internal contents validity
  """
  @spec validate(ChannelCloseMutalTx.t(), DataTx.t()) :: :ok | {:error, String.t()}
  def validate(%ChannelCloseMutalTx{} = tx, _data_tx) do
    cond do
      tx.initiator_amount + tx.responder_amount < 0 ->
        {:error, "#{__MODULE__}: Channel cannot have negative total balance"}

      true ->
        :ok
    end
  end

  @doc """
  Changes the account state (balance) of both parties and closes channel (drops channel object from chainstate)
  """
  @spec process_chainstate(
          Chainstate.account(),
          ChannelStateTree.t(),
          non_neg_integer(),
          ChannelCloseMutalTx.t(),
          DataTx.t()
        ) :: {:ok, {Chainstate.accounts(), ChannelStateTree.t()}}
  def process_chainstate(
        accounts,
        channels,
        block_height,
        %ChannelCloseMutalTx{channel_id: channel_id} = tx,
        _data_tx
      ) do
    channel = ChannelStateTree.get(channels, channel_id)

    new_accounts =
      accounts
      |> AccountStateTree.update(channel.initiator_pubkey, fn acc ->
        Account.apply_transfer!(acc, block_height, tx.initiator_amount)
      end)
      |> AccountStateTree.update(channel.responder_pubkey, fn acc ->
        Account.apply_transfer!(acc, block_height, tx.responder_amount)
      end)

    new_channels = ChannelStateTree.delete(channels, channel_id)

    {:ok, {new_accounts, new_channels}}
  end

  @doc """
  Checks whether all the data is valid according to the ChannelCloseMutalTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check(
          Chainstate.account(),
          ChannelStateTree.t(),
          non_neg_integer(),
          ChannelCloseMutalTx.t(),
          DataTx.t()
        ) :: :ok | {:error, String.t()}
  def preprocess_check(
        _accounts,
        channels,
        _block_height,
        %ChannelCloseMutalTx{} = tx,
        data_tx
      ) do
    fee = DataTx.fee(data_tx)
    channel = ChannelStateTree.get(channels, tx.channel_id)

    cond do
      tx.initiator_amount < 0 ->
        {:error, "#{__MODULE__}: Negative initiator balance"}

      tx.responder_amount < 0 ->
        {:error, "#{__MODULE__}: Negative responder balance"}

      channel == :none ->
        {:error, "#{__MODULE__}: Channel doesn't exist (already closed?)"}

      channel.initiator_amount + channel.responder_amount !=
          tx.initiator_amount + tx.responder_amount + fee ->
        {:error, "#{__MODULE__}: Wrong total balance"}

      true ->
        :ok
    end
  end

  @spec deduct_fee(
          Chainstate.accounts(),
          non_neg_integer(),
          ChannelCreateTx.t(),
          DataTx.t(),
          non_neg_integer()
        ) :: Chainstate.account()
  def deduct_fee(accounts, _block_height, _tx, _data_tx, _fee) do
    # Fee is deducted from channel
    accounts
  end

  @spec is_minimum_fee_met?(SignedTx.t()) :: boolean()
  def is_minimum_fee_met?(tx) do
    tx.data.fee >= Application.get_env(:aecore, :tx_data)[:minimum_fee]
  end

  def encode_to_list(%ChannelCloseMutalTx{} = tx, %DataTx{} = datatx) do
    [
      :binary.encode_unsigned(@version),
      Identifier.create_encoded_to_binary(tx.channel_id, :channel),
      :binary.encode_unsigned(tx.initiator_amount),
      :binary.encode_unsigned(tx.responder_amount),
      :binary.encode_unsigned(datatx.ttl),
      :binary.encode_unsigned(datatx.fee),
      :binary.encode_unsigned(datatx.nonce)
    ]
  end

  def decode_from_list(@version, [
        encoded_channel_id,
        initiator_amount,
        responder_amount,
        ttl,
        fee,
        nonce
      ]) do
    case Identifier.decode_from_binary(encoded_channel_id) do
      {:ok, %Identifier{type: :channel, value: channel_id}} ->
        payload = %ChannelCloseMutalTx{
          channel_id: channel_id,
          initiator_amount: :binary.decode_unsigned(initiator_amount),
          responder_amount: :binary.decode_unsigned(responder_amount)
        }

        DataTx.init_binary(
          ChannelCloseMutalTx,
          payload,
          [],
          :binary.decode_unsigned(fee),
          :binary.decode_unsigned(nonce),
          :binary.decode_unsigned(ttl)
        )

      {:ok, %Identifier{}} ->
        {:error, "#{__MODULE__}: Wrong channel_id identifier type"}

      {:error, _} = error ->
        error
    end
  end

  def decode_from_list(@version, data) do
    {:error, "#{__MODULE__}: decode_from_list: Invalid serialization: #{inspect(data)}"}
  end

  def decode_from_list(version, _) do
    {:error, "#{__MODULE__}: decode_from_list: Unknown version #{version}"}
  end
end
