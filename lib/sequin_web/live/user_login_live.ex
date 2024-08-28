defmodule SequinWeb.UserLoginLive do
  @moduledoc false
  use SequinWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-[80vh]">
      <div class="mx-auto max-w-sm w-full">
        <.header class="text-center">
          Log in to Sequin
          <:subtitle>
            Don't have an account?
            <.link navigate={~p"/register"} class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
          </:subtitle>
        </.header>

        <.simple_form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/users/reset_password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Logging in..." class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    socket = assign(socket, form: form)

    {:ok, socket, temporary_assigns: [form: form]}
  end
end