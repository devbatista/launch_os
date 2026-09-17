class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "admin"

      # Lockout (docs/specs/04-autenticacao-admin.md): 5 falhas → locked_at; bloqueio de 15 min.
      t.datetime :last_sign_in_at
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_at

      t.timestamps
    end
    # `User` normaliza o email (strip + downcase) antes de salvar, então o índice simples basta.
    add_index :users, :email_address, unique: true
  end
end
