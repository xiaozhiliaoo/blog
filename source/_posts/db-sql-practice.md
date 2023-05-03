---
title: SQL-DML练习
date: 2021-01-31 17:58:46
tags: SQL
categories:
  - 数据库
  - SQL
---



1. 找出所有教师名字

   ```sql
   select name from instructor;
   ```

   

2. 找出所有教师系名

   ```
   select dept_name from instructor;
   ```

   

3. 找出所有不重复的系名

   ```
   select distinct dept_name from instructor;
   ```

   

4. 找出CS系并且工资超过7000的教师名字

   ```sql
   select name from instructor where dept_name='CS' and salary>7000;
   ```

   

5. 找出所有教师名字，以及他们所在系的建筑名字

   ```mysql
   select name,instructor.dept_name,building from instructor,department where instructor.dept_name=department.dept_name;
   
   ```

   

6. 找出CS系的教师名和课程ID

   ```mysql
   select name,course_id from instructor,teaches where instructor.ID = teaches.ID and instructor.dept_name='CS';
   
   ```

   

7. 找出教师的名字和他们所教课的ID

   ```mysql
   select name,course_id from instructor natural join teaches;
   ```

   

8. 找出教师名字和他们所教课的名字

   ```
   select name,title from instructor natural join teaches,course where teaches.course_id=course.course_id;
   ```

   

9. 找出 “工资至少比Biology系某一个教师工资要高” 的所有教师名字

   ```mysql
   select distinct T.name from instructor as T, instructor as S where T.salary > S.salary and S.dept_name='Biology';
   ```

   ```mysql
   select name from instructor where salary > some(select salary from instructor where dept_name='Biology');
   ```

   

10. 找出按字母排序在Biology的所有老师

    ```mysql
    select name from instructor where dept_name='Biology' order by name;
    ```

    

11. 找出工资降序，如果工资相同姓名升序的教师

    ```
    select name from instructor order by salary desc,name asc;
    ```

    

12. 找出工资在9000到10000的教师

    ```
    select name from instructor where salary between 9000 and 10000;
    select name from instructor where salary >= 9000 and salary <= 10000;
    ```

    

13. 找出Biology系授课的所有教师名字和他们所教授的课程

    ```
    select name,course_id from instructor, teaches where instructor.ID=teaches.ID and dept_name='Biology';
    ```

    

14. 找出2009年秋季和2010年春季的所有的课程

    ```mysql
    (select course_id from section where semester='Fall' and year=2009) union (select course_id from section where semester='Spring' and year=2010) ;
    ```

    ```mysql
    
    ```

15. 找出2009年秋季和2010年春季的同时开课的课程

    ```mysql
    select distinct course_id from section where semester='Spring' and year=2009 and course_id in(select course_id from section where semester='Spring' and year=2010);
    ```

    ```java
    select course_id from section as S where semester='Fall' and year=2009 and exists(select * from section as T where  semester='Spring' and year=2010 and S.course_id=T.course_id);
    ```

    

16. 找出在2009年秋季开课和不在2010年春季开课的课程

    ```mysql
    select distinct course_id from section where semester='Spring' and year=2009 and course_id not in(select course_id from section where semester='Spring' and year=2010);
    ```

    

17. 找出CS系教师平均工资

    ```
    select avg(salary) from instructor where dept_name='CS';
    ```

    

18. 找出2010春季讲授课程的教师总数

    ```
    select count(distinct ID) from teaches where semester='Spring' and year=2010;
    ```

    

19. 找出每个系的平均工资

    ```
    select dept_name,avg(salary) from instructor group by dept_name;
    ```

    

20. 找出所有老师的平均工资

    ```
    select avg(salary) from instructor;
    ```

    

21. 找出每个系在2010年春季讲授一门课程的教师人数

    ```mysql
    SELECT 
        dept_name, COUNT(DISTINCT ID)
    FROM
        instructor
            NATURAL JOIN
        teaches
    WHERE
        semester = 'Spring' AND year = 2010
    GROUP BY dept_name;
    ```

    

22. 找出教师平均工资超过42000美元的系

    ```
    SELECT 
        dept_name, AVG(salary)
    FROM
        instructor
    GROUP BY dept_name
    HAVING AVG(salary) > 42000;
    ```

    

23. 找出2009年讲授的每个课程段，如果该课程段至少两名学生选课，找出选修该课程段的所有学生总学分的平均值

    ```mysql
    SELECT 
        course_id, semester, year, sec_id, AVG(tot_cred)
    FROM
        takes
            NATURAL JOIN
        student
    WHERE
        year = 2009
    GROUP BY course_id , semester , year , sec_id
    HAVING COUNT(ID) >= 2;
    ```

    

24. 找出既不叫Bob也不叫Ali的教师名字

    ```
    select distinct name from instructor where name not in('Bob','Ali') 
    ```

    

25. 找出不同的学生总数，选修ID为10101教师所教授的课程段

    ```mysql
    SELECT 
        COUNT(DISTINCT ID)
    FROM
        takes
    WHERE
        (course_id , sec_id, year) IN (SELECT 
                course_id, sec_id, year
            FROM
                teaches
            WHERE
                teaches.ID = 10101);
    ```

    

26. 找出 “工资比Biology系所有教师工资要高” 的所有教师名字

    ```
    select name from instructor where salary > all(select salary from instructor where dept_name='Biology');
    ```

27. 找出平均工资大于所有系平均工资的系

    ```mysql
    select dept_name from instructor group by dept_name having avg(salary) >= all(select avg(salary) from instructor group by dept_name);
    ```

    

28. 找出选修了Biology系所开设的所有课程的学生
    
29. 找出所有在2009年最多开设一次的课程
    
30. 找出所有在2009年最少开设两次的课程
    
31. 找出系平均工资超过42000美元的那些系中的教师平均工资
    
32. 所有系工资总额最大系
    
33. 所有系和他们拥有的教师数
    
34. 删除工作在Watson大楼系工作的教师
    
35. 删除平均工资低于大学平均工资的教师
    
36. 让CS系修满144学分的学生成为CS系的老师，并且其平均工资为8000
    
37. 工资低于1000教师工资增加5%
    
38. 工资低于平均数的教师工资增加5%
    
39. 工资超过1000教师涨5%，其余增长8%
    
40. 一个学生在某门课成绩既不是F，也不是空，认为修完了该课程
    
41. 找出所有课程一门也没选修的学生
    
42. 找出CS系所有学生以及他们在2009年春季选修的所有课程



其他联系平台

https://www.nowcoder.com/ta/sql





