var gulp = require('gulp'),
    path = require('path'),
    folder = require('gulp-folders'),
    concat = require('gulp-concat'),
    //insert = require('gulp-insert'),
    uglify = require('gulp-uglify'),
    notify = require('gulp-notify'),
    rename = require('gulp-rename'),
    //handleErrors = require('handleErrors'),
    source_folder = 'source/_javascript',
    destination_folder = 'source/j',
    public_folder = 'public/j';

gulp.task('scripts', folder(source_folder, function(folder){
    return gulp.src(path.join(source_folder, folder, '*.js'))
        .pipe(concat(folder + '.js'))
        // wrap in self-executing funciton
        //.pipe(insert.transform(function(contents){
        //    var prefix = "(function( window, document ){\n  'use strict';\n",
        //        suffix = "\n}( this, this.document ));"
        //    return prefix + contents + suffix;
        // }))
        .pipe(gulp.dest(destination_folder))
        .pipe(gulp.dest(public_folder))
        .pipe(rename({suffix: '.min'}))
        .pipe(uglify())
        .pipe(gulp.dest(destination_folder))
        .pipe(gulp.dest(public_folder))
        .pipe(notify({ message: 'Scripts task complete' }));
        //.on('error', handleErrors);;
}));