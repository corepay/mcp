defmodule McpStorage.StorageBehaviour do
  @moduledoc """
  Behaviour for storage clients.
  Defines the interface that all storage implementations must follow.
  """

  @callback upload_file(
              bucket :: String.t(),
              key :: String.t(),
              file_path :: String.t(),
              opts :: keyword()
            ) ::
              {:ok, map()} | {:error, term()}

  @callback download_file(
              bucket :: String.t(),
              key :: String.t(),
              destination_path :: String.t(),
              opts :: keyword()
            ) ::
              {:ok, String.t()} | {:error, term()}

  @callback delete_file(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
              :ok | {:error, term()}

  @callback list_files(bucket :: String.t(), prefix :: String.t(), opts :: keyword()) ::
              {:ok, [String.t()]} | {:error, term()}

  @callback get_file_metadata(bucket :: String.t(), key :: String.t(), opts :: keyword()) ::
              {:ok, map()} | {:error, term()}

  @callback generate_presigned_url(
              bucket :: String.t(),
              key :: String.t(),
              expires_in :: integer(),
              opts :: keyword()
            ) ::
              {:ok, String.t()} | {:error, term()}

  @optional_callbacks generate_presigned_url: 4
end
