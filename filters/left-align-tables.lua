-- Left-align all table text (used for docx output, where modelsummary
-- centers columns/cells and kable right-aligns numeric columns). Tables that
-- hold images (e.g., figure layouts) are left untouched.
local function left_rows(rows)
  for _, row in ipairs(rows) do
    for _, cell in ipairs(row.cells) do
      cell.alignment = pandoc.AlignDefault
    end
  end
end

function Table(tbl)
  local has_image = false
  tbl:walk({ Image = function() has_image = true end })
  if has_image then return nil end

  for i, spec in ipairs(tbl.colspecs) do
    tbl.colspecs[i] = { pandoc.AlignLeft, spec[2] }
  end
  left_rows(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do
    left_rows(body.head)
    left_rows(body.body)
  end
  left_rows(tbl.foot.rows)
  return tbl
end
