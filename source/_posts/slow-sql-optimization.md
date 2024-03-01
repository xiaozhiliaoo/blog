---
title: MySQL表情况概览
date: 2023-01-19 18:52:27
tags: SQL优化
categories:
  - 数据库
  - SQL
---



# 常用语句

```
show table status like '%table_x';
```

```
 SELECT
    table_name,
    engine,
    row_format,
    table_rows,
    avg_row_length AS avg_row,
    ROUND((data_length + index_length) / 1024 / 1024,
            2) AS total_mb,
    ROUND((data_length) / 1024 / 1024, 2) AS data_mb,
    ROUND((index_length) / 1024 / 1024, 2) AS index_mb
FROM
    information_schema.tables
WHERE
    table_schema = 'xxx'
AND table_name = 'yyy';
```

```
show index from table_x;
```

```
desc table_x;
```

```
show create table table_x;
```

```
SELECT COUNT(DISTINCT xxx)/COUNT(*) AS xxx_selectivity,COUNT(*) AS total  FROM table_x;
```



# 参考

https://dev.mysql.com/doc/refman/8.0/en/explain-output.html#explain-extra-information

order优化：https://dev.mysql.com/doc/refman/8.0/en/order-by-optimization.html

groupby优化：https://dev.mysql.com/doc/refman/8.0/en/group-by-optimization.html
