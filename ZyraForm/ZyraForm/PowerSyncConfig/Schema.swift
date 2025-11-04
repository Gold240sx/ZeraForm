//
//  Schema.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import PowerSync

let schema = ExtendedTable(
  name: "\(AppConfig.shared.dbPrefix)employees",
  primaryKey: "id",
  columns: [
      zf.text("email").email().notNull(),
      zf.text("name").minLength(2).maxLength(50).notNull(),
      zf.text("age").int().positive().intMin(18).intMax(120).nullable(),
      zf.text("website").url().nullable()
  ]
)
