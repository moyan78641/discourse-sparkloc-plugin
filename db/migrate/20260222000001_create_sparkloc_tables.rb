# frozen_string_literal: true

class CreateSparklocTables < ActiveRecord::Migration[7.0]
  def change
    create_table :sparkloc_oauth_apps do |t|
      t.string :client_id, null: false, limit: 64
      t.string :client_secret, null: false, limit: 64
      t.string :name, null: false, limit: 100
      t.string :description, limit: 500, default: ""
      t.text :redirect_uris, null: false
      t.integer :owner_discourse_id, null: false
      t.timestamps
    end

    add_index :sparkloc_oauth_apps, :client_id, unique: true
    add_index :sparkloc_oauth_apps, :owner_discourse_id
    add_index :sparkloc_oauth_apps, :name, unique: true

    create_table :sparkloc_authorizations do |t|
      t.integer :discourse_id, null: false
      t.string :client_id, null: false, limit: 64
      t.string :app_name, limit: 100, default: ""
      t.string :scope, limit: 200, default: "openid"
      t.string :status, limit: 20, default: "approved"
      t.timestamps
    end

    add_index :sparkloc_authorizations, :discourse_id
    add_index :sparkloc_authorizations, :client_id
    add_index :sparkloc_authorizations, :created_at

    create_table :sparkloc_lottery_records do |t|
      t.integer :topic_id, null: false
      t.string :topic_title, limit: 500
      t.integer :creator_id, null: false
      t.integer :winners_count, null: false, default: 1
      t.integer :last_floor
      t.string :seed, limit: 64
      t.json :winning_floors
      t.json :winners_info
      t.integer :valid_posts_count, default: 0
      t.boolean :published, default: false
      t.timestamps
    end

    add_index :sparkloc_lottery_records, :topic_id, unique: true
    add_index :sparkloc_lottery_records, :creator_id
  end
end
