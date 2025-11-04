//
//  Schema.swift
//  ZyraForm
//
//  Created by Michael Martell on 11/4/25.
//

import PowerSync
import ZyraForm

let schema = ZyraTable(
  name: "\(AppConfig.dbPrefix)employees",
  primaryKey: "id",
  columns: [
    zf.text("email").email().encrypted().notNull(),
    zf.text("name").minLength(2).maxLength(50).encrypted().notNull(),
    zf.text("age").int().positive().intMin(18).encrypted().intMax(120).nullable(),
    zf.text("website").url().encrypted().nullable()
  ]
)
