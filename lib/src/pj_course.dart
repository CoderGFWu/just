class PJCourse {
  String num; //序号
  String id; //课程号
  String name; //课程名称
  String teacher; //教师
  String score; //总评分
  String YP; //已经评价
  String submit; //是否提交
  String url; //评教选项链接
  // PJData pjData;
  // Map<String, String> submitData; //提交的数据

  @override
  String toString() {
    return 'PJCourse{num: $num, id: $id, name: $name, teacher: $teacher, score: $score, YP: $YP, submit: $submit, url: $url}';
  }

  PJCourse(this.num, this.id, this.name, this.teacher, this.score, this.YP,
      this.submit, this.url);
}
